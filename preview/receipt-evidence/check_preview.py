"""Exercise the local, illustrative receipt preview at four iPhone widths."""
import asyncio
import struct
import zlib
from pathlib import Path

from playwright.async_api import async_playwright

URL = "http://127.0.0.1:8088/preview/receipt-evidence/"
OUT = Path(__file__).with_name("screenshots")


def chunk(kind: bytes, content: bytes) -> bytes:
    value = kind + content
    return struct.pack(">I", len(content)) + value + struct.pack(">I", zlib.crc32(value))


def sample_png() -> bytes:
    header = struct.pack(">IIBBBBB", 200, 200, 8, 6, 0, 0, 0)
    rows = b"".join(
        b"\0" + (
            bytes((47, 140, 255, 255)) if y < 52
            else bytes((255, 138, 0, 255)) if 83 < y < 96
            else bytes((238, 242, 250, 255))
        ) * 200
        for y in range(200)
    )
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


async def main() -> None:
    OUT.mkdir(exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        for width in (320, 375, 390, 430):
            context = await browser.new_context(viewport={"width": width, "height": 812}, device_scale_factor=1)
            page = await context.new_page()
            await page.goto(URL)
            await page.locator("#record").wait_for()
            await page.locator("#search").fill("no-such-reference")
            assert await page.locator("#record").is_hidden()
            await page.locator("#search").fill("DEMO-001")
            assert await page.locator("#record").is_visible()
            await page.locator("#search").fill("")
            assert await page.locator(".brand img").evaluate("img => img.complete && img.naturalWidth > 0")
            assert await page.evaluate("document.documentElement.scrollWidth <= innerWidth")
            await page.screenshot(path=str(OUT / f"history-{width}.png"))
            await page.locator("#record").click()
            assert await page.get_by_text("Original Receipt").is_visible()
            await page.screenshot(path=str(OUT / f"detail-empty-{width}.png"))
            if width == 390:
                await page.locator("#simulate").click()
                await page.locator("#photo").set_input_files({"name": "sample.png", "mimeType": "image/png", "buffer": sample_png()})
                await page.get_by_text("Image save failed").wait_for()
                assert await page.get_by_text("Payment Verified · sample").is_visible()
                await page.locator("#photo").set_input_files({"name": "sample.png", "mimeType": "image/png", "buffer": sample_png()})
                await page.locator("#image").wait_for()
                await page.screenshot(path=str(OUT / "detail-stored-390.png"), full_page=True)
                await page.locator("#image").scroll_into_view_if_needed()
                await page.screenshot(path=str(OUT / "detail-original-390.png"))
                await page.locator("#view").click()
                assert await page.locator("#modal").is_visible()
                await page.locator("#close").click()
                await page.reload()
                await page.locator("#record").click()
                assert await page.locator("#image").is_visible()
            await context.close()
        await browser.close()
    print("Preview verified at 320, 375, 390 and 430 px; upload failure, retry, viewer and reload passed.")


if __name__ == "__main__":
    asyncio.run(main())
