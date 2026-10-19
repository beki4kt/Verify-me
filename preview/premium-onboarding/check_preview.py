"""Exercise the isolated Chekmi design preview in a real local Chromium browser."""

from pathlib import Path
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8089/preview/premium-onboarding/"
OUTPUT = Path(__file__).resolve().parents[2] / "artifacts" / "premium-preview"
OUTPUT.mkdir(parents=True, exist_ok=True)


def assert_fits(page, label):
    dimensions = page.evaluate("""() => ({
      body: document.body.scrollWidth,
      window: document.documentElement.clientWidth,
      app: document.querySelector('#app').scrollWidth,
      appWidth: document.querySelector('#app').clientWidth
    })""")
    assert dimensions["body"] <= dimensions["window"] + 1, (label, dimensions)
    assert dimensions["app"] <= dimensions["appWidth"] + 1, (label, dimensions)
    assert page.locator("img[src*='chekmi_mark']").first.evaluate("img => img.naturalWidth > 0"), label


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        headless=True,
    )
    for width, height in [(320, 700), (375, 812), (390, 844), (430, 932)]:
        page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
        page.set_default_timeout(7000)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(URL, wait_until="networkidle")
        assert page.locator("#splash.running").count() == 1
        page.wait_for_timeout(1550)
        assert page.get_by_role("heading", name="Payments, verified.").is_visible()
        assert_fits(page, f"welcome {width}")
        page.screenshot(path=str(OUTPUT / f"welcome-{width}.png"))

        # Existing workspace journey. Code advances to the staff form, never to a fake dashboard.
        page.get_by_role("button", name="Connect Workspace").click()
        assert page.get_by_role("heading", name="Welcome back").is_visible()
        page.get_by_label("Workspace code").fill("CK-PREVIEW")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Team sign in").is_visible()
        assert_fits(page, f"staff login {width}")
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "staff-login.png"))
        page.get_by_label("Go back").click()
        page.get_by_role("button", name="Business owner").click()
        page.get_by_label("Email address").fill("owner@example.com")
        page.get_by_label("Password", exact=True).fill("preview-password")
        page.get_by_role("button", name="Sign In").click()
        assert page.get_by_text("Sign-in is disabled in this design preview.", exact=False).is_visible()
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "owner-login.png"))
        page.get_by_label("Go back").click()

        # New business journey. Selection state and values persist while navigating.
        page.get_by_role("button", name="Get Started").click()
        page.get_by_role("button", name="Shop").click()
        assert page.get_by_role("button", name="Shop").get_attribute("aria-pressed") == "true"
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "business-type.png"))
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Set your workflow").is_visible()
        page.get_by_role("button", name="My Team").click()
        page.get_by_role("button", name="Review", exact=True).click()
        assert page.get_by_role("button", name="Review", exact=True).get_attribute("aria-pressed") == "true"
        page.get_by_label("Go back").click()
        assert page.get_by_role("button", name="Shop").get_attribute("aria-pressed") == "true"
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("button", name="My Team").get_attribute("aria-pressed") == "true"
        assert page.get_by_role("button", name="Review", exact=True).get_attribute("aria-pressed") == "true"
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "workflow.png"))
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Choose a plan").is_visible()
        assert page.get_by_role("button", name="Basic", exact=False).is_disabled()
        assert page.get_by_text("Request quote").is_visible()
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "plans.png"))
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Create your business").is_visible()
        page.get_by_role("button", name="Review request").click()
        assert page.get_by_role("alert").is_visible()
        page.get_by_label("Business name").fill("Test Shop")
        page.get_by_label("Your name").fill("Test Owner")
        page.get_by_label("Phone", exact=True).fill("+251911111111")
        page.get_by_label("Email", exact=True).fill("owner@example.com")
        page.get_by_label("Create password").fill("tencharacters")
        page.get_by_label("Receiving account").fill("0911111111")
        if width == 390:
            page.locator("#app").evaluate("el => el.scrollTop = 0")
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "registration.png"))
            page.locator("#app").evaluate("el => el.scrollTop = el.scrollHeight")
            page.screenshot(path=str(OUTPUT / "registration-bottom.png"))
        page.get_by_role("button", name="Review request").click()
        assert page.get_by_role("heading", name="Ready to request access").is_visible()
        assert page.get_by_text("No business was created", exact=False).is_visible()
        assert_fits(page, f"summary {width}")
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "request-summary.png"))
        page.get_by_role("button", name="Back to welcome").click()
        page.get_by_role("button", name="Preview", exact=True).click()
        assert page.get_by_text("no bank lookup", exact=False).is_visible()
        if width == 390:
            page.wait_for_timeout(450)
            page.screenshot(path=str(OUTPUT / "illustrative-preview.png"))
        assert not errors, errors
        page.close()
        print(f"PASS {width}x{height}: all three journeys, no overflow, no page errors")

    page = browser.new_page(viewport={"width": 1366, "height": 900}, device_scale_factor=1)
    page.goto(URL, wait_until="networkidle")
    page.wait_for_timeout(1550)
    page.screenshot(path=str(OUTPUT / "desktop-studio.png"))
    page.get_by_role("button", name="Replay splash").click()
    assert page.locator("#splash.running").count() == 1
    page.wait_for_timeout(610)
    page.locator("#phone").screenshot(path=str(OUTPUT / "splash-reveal.png"))
    page.get_by_label("Preview viewport").select_option("320")
    assert page.locator("#phone").evaluate("el => getComputedStyle(el).width") == "320px"
    print("PASS desktop studio: viewport switch and splash replay")
    landscape = browser.new_page(viewport={"width": 844, "height": 390}, device_scale_factor=1)
    landscape.goto(URL, wait_until="networkidle")
    landscape.wait_for_timeout(1550)
    assert_fits(landscape, "landscape")
    assert landscape.get_by_role("button", name="Get Started").is_visible()
    landscape.screenshot(path=str(OUTPUT / "landscape.png"))
    print("PASS landscape: full-width preview without overflow")
    reduced = browser.new_page(viewport={"width": 390, "height": 844}, reduced_motion="reduce")
    reduced.goto(URL, wait_until="networkidle")
    reduced.wait_for_timeout(300)
    assert reduced.get_by_role("heading", name="Payments, verified.").is_visible()
    assert reduced.locator("#splash.running").count() == 0
    print("PASS reduced motion: splash settles promptly")
    browser.close()
