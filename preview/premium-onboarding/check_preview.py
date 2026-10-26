"""Browser regression checks for the isolated Chekmi onboarding preview."""

from pathlib import Path
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8089/preview/premium-onboarding/"
OUTPUT = Path(__file__).resolve().parents[2] / "artifacts" / "premium-preview"
OUTPUT.mkdir(parents=True, exist_ok=True)


def fits(page, label):
    dimensions = page.evaluate("""() => ({
      body: document.body.scrollWidth,
      window: document.documentElement.clientWidth,
      app: document.querySelector('#app').scrollWidth,
      appWidth: document.querySelector('#app').clientWidth
    })""")
    assert dimensions["body"] <= dimensions["window"] + 1, (label, dimensions)
    assert dimensions["app"] <= dimensions["appWidth"] + 1, (label, dimensions)
    assert page.locator("img[src*='chekmi_mark']").first.evaluate("img => img.naturalWidth > 0"), label


def shot(page, filename):
    page.wait_for_timeout(430)
    page.screenshot(path=str(OUTPUT / filename))


def to_welcome(page):
    page.goto(URL, wait_until="networkidle")
    page.wait_for_timeout(1550)
    assert page.get_by_role("heading", name="Payments, verified.").is_visible()


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        headless=True,
    )
    for width, height in [(320, 700), (375, 812), (390, 844), (430, 932)]:
        page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
        page.set_default_timeout(7000)
        errors = []
        remote_requests = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("request", lambda request: remote_requests.append(request.url)
                if request.url.startswith("http") and not request.url.startswith("http://127.0.0.1:8089/") else None)
        to_welcome(page)
        fits(page, f"welcome {width}")
        primary = page.get_by_role("button", name="Get Started")
        assert 48 <= primary.bounding_box()["height"] <= 52
        if width == 390:
            shot(page, "welcome-390.png")
        if width == 320:
            shot(page, "welcome-320.png")

        # Connection step has only the code field. Its syntax check is local,
        # and the following screen does not claim that the workspace exists.
        page.get_by_role("button", name="Connect Workspace").click()
        assert page.get_by_role("heading", name="Connect Workspace").is_visible()
        assert page.locator("input").count() == 1
        assert page.locator("input[type=password]").count() == 0
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("alert").is_visible()
        page.get_by_label("Workspace code").fill(" ck-preview ")
        if width == 390:
            shot(page, "connect-code.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Welcome back").is_visible()
        assert page.get_by_text("Workspace CK-PREVIEW").is_visible()
        assert page.get_by_label("Phone number", exact=True).is_visible()
        if width == 390:
            shot(page, "workspace-login.png")
        page.get_by_label("Phone number", exact=True).fill("911111111")
        page.get_by_label("Password", exact=True).fill("example-pass")
        page.get_by_role("button", name="Sign In", exact=True).click()
        assert page.get_by_text("No membership was checked", exact=False).is_visible()
        assert "#staff" in page.url

        # Phone-first owner screen and explicit legacy email compatibility.
        page.get_by_role("button", name="Business owner? Sign in").click()
        assert page.get_by_role("heading", name="Welcome back").is_visible()
        assert page.get_by_label("Phone number", exact=True).is_visible()
        assert page.locator("input[type=email]").count() == 0
        page.get_by_label("Phone number", exact=True).fill("911111111")
        page.get_by_label("Password", exact=True).fill("example-pass")
        if width == 390:
            shot(page, "owner-phone.png")
        page.get_by_role("button", name="Sign In", exact=True).click()
        assert page.get_by_text("Owner phone sign-in is not configured", exact=False).is_visible()
        page.get_by_role("button", name="Use email to sign in").click()
        assert page.get_by_label("Email address").is_visible()
        if width == 390:
            shot(page, "owner-email-legacy.png")
        page.get_by_label("Go back").click()
        page.get_by_role("button", name="Explore dashboard preview").click()
        assert page.get_by_text("Illustrative workspace").is_visible()
        assert page.get_by_text("server-authorized membership", exact=False).is_visible()
        if width == 390:
            shot(page, "workspace-dashboard-preview.png")
        page.get_by_label("Go back").click()
        page.get_by_label("Go back").click()
        page.get_by_label("Go back").click()
        assert page.get_by_role("heading", name="Payments, verified.").is_visible()

        # Business presets, workflow, real plan catalog copy, and phone-only
        # registration remain local, with no fake activation.
        page.get_by_role("button", name="Get Started").click()
        assert page.locator(".choice").count() == 5
        assert page.get_by_role("button", name="Events & Venues").evaluate(
            "el => getComputedStyle(el).gridColumnStart"
        ) == "1"
        page.get_by_role("button", name="Shop & Retail").click()
        assert page.get_by_role("button", name="Shop & Retail").get_attribute("aria-pressed") == "true"
        page.evaluate("window.screenBeforeSelection = document.querySelector('.screen')")
        page.get_by_role("button", name="Services & Professionals").click()
        assert page.evaluate("document.querySelector('.screen') === window.screenBeforeSelection")
        page.get_by_role("button", name="Shop & Retail").click()
        if width == 390:
            shot(page, "business-type.png")
        if width == 320:
            shot(page, "business-type-320.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="What kind of shop?").is_visible()
        assert page.locator(".subtype-choice").count() == 6
        assert min(button.bounding_box()["height"] for button in page.locator(".subtype-choice").all()) >= 44
        assert not page.get_by_role("button", name="Restaurant", exact=True).count()
        page.evaluate("window.screenBeforeSelection = document.querySelector('.screen')")
        page.get_by_role("button", name="Online Store").click()
        assert page.evaluate("document.querySelector('.screen') === window.screenBeforeSelection")
        page.get_by_role("button", name="Grocery / Supermarket").click()
        if width == 390:
            shot(page, "shop-subtypes.png")
        if width == 320:
            shot(page, "shop-subtypes-320.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Where do you receive payments?").is_visible()
        assert page.get_by_role("button", name="Single Counter").get_attribute("aria-pressed") == "true"
        assert min(button.bounding_box()["height"] for button in page.locator(".workflow-choice").all()) >= 44
        page.evaluate("window.screenBeforeSelection = document.querySelector('.screen')")
        page.get_by_role("button", name="Multiple Counters").click()
        assert page.evaluate("document.querySelector('.screen') === window.screenBeforeSelection")
        assert page.get_by_text("Counter labels and staff attribution").is_visible()
        assert page.locator("#setup-mode").inner_text() == "My Team"
        page.get_by_role("button", name="Adjust setup").click()
        page.get_by_role("button", name="Review", exact=True).click()
        assert page.evaluate("document.querySelector('.screen') === window.screenBeforeSelection")
        assert page.get_by_text("authorized member completes payments").is_visible()
        page.get_by_label("Track payments by").select_option("customer")
        assert page.locator("#setup-reference").inner_text() == "Customer"
        page.get_by_label("Go back").click()
        assert page.get_by_role("button", name="Grocery / Supermarket").get_attribute("aria-pressed") == "true"
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("button", name="Multiple Counters").get_attribute("aria-pressed") == "true"
        assert page.locator("#setup-reference").inner_text() == "Customer"
        if width == 390:
            shot(page, "workflow.png")
        if width == 320:
            shot(page, "workflow-320.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("button", name="Basic", exact=False).is_disabled()
        assert page.get_by_text("Request quote").is_visible()
        page.evaluate("window.screenBeforeSelection = document.querySelector('.screen')")
        page.get_by_role("button", name="Quarterly").click()
        assert page.evaluate("document.querySelector('.screen') === window.screenBeforeSelection")
        assert page.get_by_text("ETB 3,000 / 3 mo").is_visible()
        if width == 390:
            shot(page, "plans.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_label("Phone number", exact=True).is_visible()
        assert page.locator("input[type=email]").count() == 0
        page.get_by_role("button", name="Review request").click()
        assert page.get_by_role("alert").is_visible()
        page.get_by_label("Business name").fill("Test Shop")
        page.get_by_label("Owner name").fill("Test Owner")
        page.get_by_label("Phone number", exact=True).fill("911111111")
        page.get_by_label("Create password").fill("tencharacters")
        page.get_by_label("Receiving account").fill("0911111111")
        assert "tencharacters" not in page.evaluate("sessionStorage.getItem('chekmi-preview-draft')")
        if width == 390:
            page.locator("#app").evaluate("el => el.scrollTop = 0")
            shot(page, "registration.png")
            page.locator("#app").evaluate("el => el.scrollTop = el.scrollHeight")
            shot(page, "registration-bottom.png")
        page.get_by_role("button", name="Review request").click()
        assert page.get_by_text("No business was created", exact=False).is_visible()
        if width == 390:
            shot(page, "request-summary.png")
        page.get_by_role("button", name="Back to welcome").click()

        # Events is receipt verification with remembered context, not ticketing.
        page.get_by_role("button", name="Get Started").click()
        page.get_by_role("button", name="Events & Venues").click()
        assert page.get_by_role("button", name="Events & Venues").get_attribute("aria-pressed") == "true"
        if width == 390:
            shot(page, "events-selected.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="What type of event?").is_visible()
        assert page.locator(".subtype-choice").count() == 5
        page.get_by_role("button", name="Concert / Festival").click()
        if width == 390:
            shot(page, "events-subtypes.png")
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("heading", name="Where do you collect payments?").is_visible()
        page.get_by_role("button", name="Multiple Stations").click()
        assert page.locator("#setup-reference").inner_text() == "Station"
        assert page.locator("#setup-mode").inner_text() == "My Team"
        assert page.locator("#setup-review").inner_text() == "Review"
        if width == 390:
            shot(page, "events-workflow.png")
        page.get_by_role("button", name="See event workspace").click()
        assert page.get_by_role("heading", name="Event payments").is_visible()
        page.get_by_label("Category").select_option("Merchandise")
        page.get_by_label("Station").select_option("Hall kiosk")
        page.get_by_role("button", name="Scan receipt").click()
        assert page.get_by_role("status").last.is_visible()
        page.get_by_label("Receipt reference").fill("PREVIEW-123")
        page.get_by_role("button", name="Check receipt").click()
        assert page.get_by_text("No bank lookup or ledger write", exact=False).is_visible()
        assert page.get_by_label("Category").input_value() == "Merchandise"
        assert page.get_by_label("Station").input_value() == "Hall kiosk"
        assert page.get_by_text("Sample only").is_visible()
        assert not remote_requests, remote_requests
        if width == 390:
            shot(page, "events-preview.png")
            page.locator("#app").evaluate("el => el.scrollTop = el.scrollHeight")
            shot(page, "events-ledger.png")
        fits(page, f"events {width}")
        page.get_by_label("Go back").click()
        page.get_by_role("button", name="Continue").click()
        assert page.get_by_role("button", name="Basic", exact=False).is_disabled()
        page.get_by_label("Go back").click()
        page.get_by_label("Go back").click()
        page.get_by_label("Go back").click()
        page.get_by_label("Go back").click()
        page.get_by_role("button", name="Explore Preview").click()
        assert page.get_by_role("heading", name="Try a receipt").is_visible()
        page.get_by_role("button", name="Check sample receipt").click()
        assert page.get_by_text("Enter a receipt reference and a valid amount.").is_visible()
        page.get_by_role("button", name="Verified", exact=True).click()
        assert page.get_by_label("Receipt reference").input_value() == "CK-DEMO-PAID"
        page.get_by_role("button", name="Check sample receipt").click()
        page.get_by_text("Sample: payment verified").wait_for()
        page.get_by_role("button", name="Duplicate", exact=True).click()
        page.get_by_role("button", name="Check sample receipt").click()
        page.get_by_text("Sample: duplicate payment").wait_for()
        page.get_by_role("button", name="Pending", exact=True).click()
        page.get_by_role("button", name="Check sample receipt").click()
        page.get_by_text("Sample: verification pending").wait_for()
        page.get_by_label("Receipt reference").fill("UNKNOWN-REF")
        page.get_by_role("button", name="Check sample receipt").click()
        page.get_by_text("Sample: payment not verified").wait_for()
        if width == 390:
            shot(page, "interactive-preview.png")
            page.get_by_role("button", name="Verified", exact=True).click()
            page.get_by_role("button", name="Check sample receipt").click()
            page.get_by_text("Sample: payment verified").wait_for()
            shot(page, "interactive-preview-verified.png")
        fits(page, f"interactive preview {width}")
        assert not remote_requests, remote_requests
        assert not errors, errors
        page.close()
        print(f"PASS {width}x{height}: all five journeys, local-only auth, no overflow or script errors")

    # Every subtype has stable IDs, valid choices, and an applicable reference.
    matrix = browser.new_page(viewport={"width": 390, "height": 844})
    to_welcome(matrix)
    config = matrix.evaluate("""() => Object.entries(window.ChekmiPresets).map(([id, category]) => ({
      id, title: category.title, references: category.references.map(([key]) => key),
      subtypes: Object.entries(category.subtypes).map(([key, item]) => ({
        key, title: item.title, question: item.question, choices: item.choices,
        defaultWorkflow: item.defaultWorkflow
      }))
    }))""")
    assert len(config) == 5
    for category in config:
        assert len(category["subtypes"]) >= 4
        assert len({item["key"] for item in category["subtypes"]}) == len(category["subtypes"])
        for subtype in category["subtypes"]:
            assert subtype["question"] and len(subtype["choices"]) >= 2
            assert subtype["defaultWorkflow"] == subtype["choices"][0]["id"]
            assert len({choice["id"] for choice in subtype["choices"]}) == len(subtype["choices"])
            for choice in subtype["choices"]:
                assert choice["reference"] in category["references"]
                assert choice["mode"] in ("solo", "team")
                assert choice["review"] in ("automatic", "review_required")
                assert not set(choice["features"]) & {"tickets", "admission", "inventory"}

    matrix.get_by_role("button", name="Get Started").click()
    journeys = [
        ("Food & Hospitality", "Restaurant", "How do you serve customers?", "Table"),
        ("Services & Professionals", "Salon / Beauty", "How do you take payments?", "Booking"),
        ("General & Personal", "Personal Payments", "How will you track payments?", "Payment ref"),
    ]
    for category, subtype, question, reference in journeys:
        matrix.get_by_role("button", name=category).click()
        matrix.get_by_role("button", name="Continue").click()
        assert matrix.get_by_role("button", name=subtype).is_visible()
        matrix.get_by_role("button", name=subtype).click()
        matrix.get_by_role("button", name="Continue").click()
        assert matrix.get_by_role("heading", name=question).is_visible()
        assert matrix.locator("#setup-reference").inner_text() == reference
        if subtype == "Restaurant":
            shot(matrix, "restaurant-workflow.png")
        if subtype == "Personal Payments":
            shot(matrix, "personal-workflow.png")
        matrix.get_by_label("Go back").click()
        matrix.get_by_label("Go back").click()
    print("PASS all category/subtype configurations and tailored food, service, personal journeys")
    matrix.close()

    direct = browser.new_page(viewport={"width": 390, "height": 844})
    direct.goto(URL + "#plans", wait_until="networkidle")
    assert direct.url.endswith("#business")
    assert direct.get_by_role("heading", name="Choose your business").is_visible()
    direct.close()

    desktop = browser.new_page(viewport={"width": 1366, "height": 900})
    to_welcome(desktop)
    shot(desktop, "desktop-studio.png")
    desktop.get_by_role("button", name="Replay splash").click()
    assert desktop.locator("#splash.running").count() == 1
    desktop.wait_for_timeout(610)
    desktop.locator("#phone").screenshot(path=str(OUTPUT / "splash-reveal.png"))
    desktop.get_by_label("Preview viewport").select_option("320")
    assert desktop.locator("#phone").evaluate("el => getComputedStyle(el).width") == "320px"
    landscape = browser.new_page(viewport={"width": 844, "height": 390})
    to_welcome(landscape)
    fits(landscape, "landscape")
    landscape.screenshot(path=str(OUTPUT / "landscape.png"))
    reduced = browser.new_page(viewport={"width": 390, "height": 844}, reduced_motion="reduce")
    reduced.goto(URL, wait_until="networkidle")
    reduced.wait_for_timeout(300)
    assert reduced.get_by_role("heading", name="Payments, verified.").is_visible()
    assert reduced.locator("#splash.running").count() == 0
    print("PASS desktop, landscape, splash replay, and reduced motion")
    browser.close()
