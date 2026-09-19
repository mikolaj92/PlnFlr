import Foundation
import PlnFlrLayout

private let iconRoom = #"<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 10v10h14V10"/></svg>"#
private let iconAdd = #"<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14"/><path d="M5 12h14"/></svg>"#

func escape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func attr(_ value: String) -> String { escape(value) }

func htmlPage(title: String, navActive: String, rooms: [SavedRoom], content: String) -> String {
    let roomItems = rooms.map { room in
        navItem(label: room.name, href: "/rooms/\(room.id)", icon: iconRoom, key: room.id, active: navActive == room.id)
    }.joined()
    return """
    <!doctype html>
    <html lang="pl">
    <head>
    \(themeBoot)
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>\(escape(title)) · PlnFlr</title>
    \(headAssets)
    <link rel="stylesheet" href="/static/app.css">
    \(shellBoot)
    </head>
    <body class="app-shell">
    <aside id="sidebar" class="sidebar z-40 app-sidebar" data-side="left" data-collapsible="icon" data-initial-open="true" data-initial-mobile-open="false" data-breakpoint="768" aria-label="Nawigacja">
      <nav class="app-sidebar__nav" aria-label="Nawigacja">
        <header class="app-sidebar__brand">
          <a class="font-semibold" href="/" data-no-htmx="true"><span>PlnFlr</span></a>
        </header>
        <section class="scrollbar app-sidebar__scroll">
          <div role="group" aria-labelledby="platform-group-1">
            <h3 id="platform-group-1">Pokoje</h3>
            <ul role="list">\(roomItems)</ul>
          </div>
          <div role="group" aria-labelledby="platform-group-2">
            <h3 id="platform-group-2">Akcje</h3>
            <ul role="list">\(navItem(label: "Nowy pokój", href: "/rooms/new", icon: iconAdd, key: "new-room", active: navActive == "new-room"))</ul>
          </div>
        </section>
        <footer>
          <div class="app-sidebar__footer" data-platform-foot>
            <div class="app-stack app-stack--tight w-full" data-platform-auth>
              <a class="btn w-full" data-variant="primary" data-size="sm" href="/" data-no-htmx="true">Login</a>
            </div>
          </div>
        </footer>
      </nav>
    </aside>
    <main class="main app-main" id="app-main">
      <header class="app-main-header bg-background">
        <div class="app-main-header__inner">
          <button id="sidebar-toggle" type="button" data-sidebar-toggle="sidebar" aria-controls="sidebar" aria-expanded="false" aria-label="Toggle navigation" class="btn app-main-header__toggle" data-variant="ghost" data-size="icon-sm">
            <svg class="lucide lucide-panel-left icon-themed" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect width="18" height="18" x="3" y="3" rx="2" /><path d="M9 3v18" /></svg>
          </button>
          <div class="loading htmx-indicator app-header__loading" aria-hidden="true"><span class="spinner" aria-hidden="true"></span></div>
          <div class="app-main-header__title text-sm text-muted-foreground truncate" data-shell-page-title>\(escape(title))</div>
          <div class="app-main-header__controls">\(themeLocale)</div>
        </div>
      </header>
      <div class="app-main-content">
        <div id="main-content" class="app-content-inner" data-nav-active="\(attr(navActive))" data-page-title="\(attr(title))">
          \(content)
        </div>
      </div>
    </main>
    </body>
    </html>
    """
}

func newRoomPage(rooms: [SavedRoom]) -> String {
    htmlPage(
        title: "Nowy pokój",
        navActive: "new-room",
        rooms: rooms,
        content: """
        <section class="app-stack">
          <div class="card">
            <header>
              <h1 class="text-base font-semibold">Nowy pokój</h1>
              <p class="text-sm text-muted-foreground">Każdy pokój trzyma własny obrys i materiał. Na razie jeden otwarty użytkownik; później konta dostaną osobne listy.</p>
            </header>
            <section>
              <form class="app-stack" method="post" action="/rooms">
                <label class="app-stack app-stack--tight" for="name">
                  <span class="text-sm font-medium">Nazwa</span>
                  <input id="name" class="input" name="name" value="Pokój" required>
                </label>
                <button class="btn" type="submit" data-variant="primary">Dodaj pokój</button>
              </form>
            </section>
          </div>
        </section>
        """
    )
}

func roomPage(room: SavedRoom, rooms: [SavedRoom], form: [String: String], scanMaxBytes: Int) -> String {
    func v(_ key: String) -> String { form[key] ?? "" }
    let checked: (String, String) -> String = { name, value in
        v(name) == value ? " checked" : ""
    }
    let selected: (String, String) -> String = { name, value in
        v(name) == value ? " selected" : ""
    }
    let expansion = v("expansion_mm")
    let expansionAuto = expansion.isEmpty ? "true" : "false"
    let expansionShown = expansion.isEmpty ? "10" : expansion
    let content = """
    <section class="app-stack" x-bind:style="'--map-deg:' + mapDeg + 'deg'" x-data="{
            shape: '\(attr(v("shape")))',
            kind: '\(attr(v("kind")))',
            kindB: '\(attr(v("kind_b")))',
            split: '\(attr(v("split")))',
            angleDeg: \(Int(v("angle_deg")) ?? 0),
            groutMm: \(Int(v("grout_mm")) ?? 3),
            boardsPerPack: \(Int(v("boards_per_pack")) ?? 8),
            expansionMm: \(Int(expansionShown) ?? 10),
            expansionAuto: \(expansionAuto),
            mapDeg: 0
          }">
      <div class="card">
        <header>
          <h1 class="text-base font-semibold">\(escape(room.name))</h1>
          <p class="text-sm text-muted-foreground">Ty podajesz obrys, kąt i ewentualną podziałkę — albo wgrywasz skan RoomPlan (USDZ). Komputer liczy dylatację, siatkę, docinki, listwy na progach, ilość i kolejność.</p>
        </header>
        <section>
          <fieldset class="app-stack app-stack--tight">
            <legend class="text-sm font-medium">Skan RoomPlan</legend>
            \(fileUpload(id: "room-scan", action: "/rooms/\(room.id)/scan", maxBytes: scanMaxBytes))
          </fieldset>
          <form class="app-stack" method="post" action="/rooms/\(room.id)/plan" hx-post="/rooms/\(room.id)/plan" hx-target="#plan-panel" hx-swap="innerHTML" hx-indicator="#plan-indicator">
            <fieldset class="app-stack app-stack--tight">
              <legend class="text-sm font-medium">Kształt</legend>
              <div class="app-cluster">
                <label class="text-sm"><input type="radio" name="shape" value="rect" x-model="shape"\(checked("shape", "rect"))> Prostokąt</label>
                <label class="text-sm"><input type="radio" name="shape" value="l" x-model="shape"\(checked("shape", "l"))> Litera L</label>
                <label class="text-sm"><input type="radio" name="shape" value="polygon" x-model="shape"\(checked("shape", "polygon"))> Wielokąt</label>
              </div>
            </fieldset>
            <div class="app-card-grid" x-show="shape === 'rect'">
              \(field("width_m", "Szerokość (m)", v("width_m")))
              \(field("height_m", "Długość (m)", v("height_m")))
            </div>
            <div class="app-card-grid" x-show="shape === 'l'" x-cloak>
              \(field("l_span_x_m", "Rozpiętość X (m)", v("l_span_x_m")))
              \(field("l_span_y_m", "Rozpiętość Y (m)", v("l_span_y_m")))
              \(field("l_cutout_x_m", "Wycięcie X (m)", v("l_cutout_x_m")))
              \(field("l_cutout_y_m", "Wycięcie Y (m)", v("l_cutout_y_m")))
            </div>
            <label class="app-stack app-stack--tight" for="vertices" x-show="shape === 'polygon'" x-cloak>
              <span class="text-sm font-medium">Wierzchołki (m), jeden na linię: x,y</span>
              <textarea id="vertices" class="input" name="vertices" rows="6">\(escape(v("vertices")))</textarea>
            </label>
            <fieldset class="app-stack app-stack--tight">
              <legend class="text-sm font-medium">Otwory (opcjonalne)</legend>
              <p class="text-sm text-muted-foreground">Dodaj dowolną liczbę otworów jako prostokąty lub wielokąty.</p>
              \(area("hole_rectangles", "Prostokąty (m), jeden na linię: x,y,szerokość,wysokość", v("hole_rectangles"), 3))
              \(area("hole_vertices", "Wielokąty (m): x,y na linię, pusta linia oddziela otwory", v("hole_vertices"), 6))
              \(area("door_rectangles", "Progi / drzwi (m): x,y,szerokość,wysokość — odcięcie i listwa", v("door_rectangles"), 3))
              \(area("door_vertices", "Progi jako wielokąty (m): x,y na linię, pusta linia oddziela listwy", v("door_vertices"), 6))
              \(area("window_segments", "Okna (m): x1,y1,x2,y2 — deski prostopadle do ściany", v("window_segments"), 3))
            </fieldset>
            <fieldset class="app-stack app-stack--tight">
              <legend class="text-sm font-medium">Materiał</legend>
              <div class="app-cluster">
                <label class="text-sm"><input type="radio" name="kind" value="plank" x-model="kind"\(checked("kind", "plank"))> Deska / panel</label>
                <label class="text-sm"><input type="radio" name="kind" value="tile" x-model="kind"\(checked("kind", "tile"))> Płytka</label>
              </div>
            </fieldset>
            <div class="app-card-grid" x-show="kind === 'plank' || split !== 'none'">
              \(field("plank_length_m", "Długość deski (m)", v("plank_length_m")))
              \(field("plank_width_m", "Szerokość deski (m)", v("plank_width_m")))
              <label class="app-stack app-stack--tight" for="boards_per_pack">
                <span class="text-sm font-medium">Sztuk w paczce: <span x-text="boardsPerPack"></span></span>
                <input id="boards_per_pack" class="input" type="range" name="boards_per_pack" min="4" max="16" step="1" value="\(attr(v("boards_per_pack")))" x-model.number="boardsPerPack">
              </label>
            </div>
            <div class="app-card-grid" x-show="kind === 'tile' || (split !== 'none' && kindB === 'tile')" x-cloak>
              \(field("tile_length_m", "Długość płytki (m)", v("tile_length_m")))
              \(field("tile_width_m", "Szerokość płytki (m)", v("tile_width_m")))
              <label class="app-stack app-stack--tight" for="grout_mm">
                <span class="text-sm font-medium">Fuga: <span x-text="groutMm"></span> mm</span>
                <input id="grout_mm" class="input" type="range" name="grout_mm" min="1" max="10" step="1" value="\(attr(v("grout_mm")))" x-model.number="groutMm">
              </label>
            </div>
            <div class="app-card-grid">
              <div class="app-stack app-stack--tight">
                <div class="app-cluster app-cluster--between">
                  <label class="text-sm font-medium" for="expansion_mm">Dylatacja: <span x-show="!expansionAuto"><span x-text="expansionMm"></span> mm</span><span x-show="expansionAuto" x-cloak>auto</span></label>
                  <label class="text-sm" for="expansion_auto"><input id="expansion_auto" type="checkbox" x-model="expansionAuto"> auto</label>
                </div>
                <input type="hidden" name="expansion_mm" x-bind:value="expansionAuto ? '' : expansionMm" value="\(attr(expansion))">
                <input id="expansion_mm" class="input" type="range" min="0" max="30" step="1" value="\(attr(expansionShown))" x-model.number="expansionMm" x-bind:disabled="expansionAuto">
              </div>
              <label class="app-stack app-stack--tight" for="direction">
                <span class="text-sm font-medium">Kierunek</span>
                <select id="direction" class="input" name="direction">
                  <option value="along_long"\(selected("direction", "along_long"))>Wzdłuż dłuższego boku</option>
                  <option value="along_short"\(selected("direction", "along_short"))>Wzdłuż krótszego boku</option>
                  <option value="into_window"\(selected("direction", "into_window"))>Prostopadle do okna</option>
                </select>
              </label>
              <label class="app-stack app-stack--tight" for="stagger" x-show="kind === 'plank'">
                <span class="text-sm font-medium">Przesunięcie spoin</span>
                <select id="stagger" class="input" name="stagger">
                  <option value="third"\(selected("stagger", "third"))>1/3</option>
                  <option value="half"\(selected("stagger", "half"))>1/2 (cegiełka)</option>
                </select>
              </label>
              <label class="app-stack app-stack--tight" for="angle_deg">
                <span class="text-sm font-medium">Kąt siatki: <span x-text="angleDeg"></span>°</span>
                <input id="angle_deg" class="input" type="range" name="angle_deg" min="0" max="90" step="1" value="\(attr(v("angle_deg")))" x-model.number="angleDeg">
              </label>
              <label class="app-stack app-stack--tight" for="map_deg">
                <span class="text-sm font-medium">Obrót mapy: <span x-text="mapDeg"></span>°</span>
                <input id="map_deg" class="input" type="range" min="0" max="360" step="1" x-model.number="mapDeg">
              </label>
            </div>
            <fieldset class="app-stack app-stack--tight">
              <legend class="text-sm font-medium">Podziałka</legend>
              <div class="app-cluster">
                <label class="text-sm"><input type="radio" name="split" value="none" x-model="split"\(checked("split", "none"))> Cały pokój jednym materiałem</label>
                <label class="text-sm"><input type="radio" name="split" value="x" x-model="split"\(checked("split", "x"))> Linia pionowa</label>
                <label class="text-sm"><input type="radio" name="split" value="y" x-model="split"\(checked("split", "y"))> Linia pozioma</label>
              </div>
            </fieldset>
            <div class="app-card-grid" x-show="split !== 'none'" x-cloak>
              \(field("split_at_m", "Linia od krawędzi (m, puste = środek)", v("split_at_m"), placeholder: "auto"))
              <label class="app-stack app-stack--tight" for="kind_b">
                <span class="text-sm font-medium">Druga strefa</span>
                <select id="kind_b" class="input" name="kind_b" x-model="kindB">
                  <option value="plank"\(selected("kind_b", "plank"))>Deska / panel</option>
                  <option value="tile"\(selected("kind_b", "tile"))>Płytka</option>
                </select>
              </label>
            </div>
            <button class="btn" type="submit" data-variant="primary">Rozłóż podłogę</button>
          </form>
        </section>
      </div>
      <p id="plan-indicator" class="htmx-indicator text-sm text-muted-foreground">Liczenie siatki…</p>
      <div id="plan-panel"></div>
    </section>
    """
    return htmlPage(title: room.name, navActive: room.id, rooms: rooms, content: content)
}

func planFragment(_ plan: LayoutPlan) -> String {
    let svg = planToSvg(plan)
    let net = netM2(plan.bom.areaNetMm2)
    var extra = ""
    if plan.boms.count > 1 {
        let rows = plan.boms.map { bom in
            "<tr><td>\(escape(bom.label))</td><td>\(bom.pieces)</td><td>\(bom.fullBoards)</td><td>\(bom.packs.map(String.init) ?? "—")</td><td>\(escape(bom.wastePct))%</td></tr>"
        }.joined()
        extra += """
        <div class="card"><header><h2 class="text-base font-semibold">Strefy</h2></header><section>
        <div class="table-container app-table-wrap"><table class="table"><thead><tr><th>Strefa</th><th>Sztuki</th><th>Do kupienia</th><th>Paczki</th><th>Odpad</th></tr></thead><tbody>\(rows)</tbody></table></div>
        </section></div>
        """
    }
    if !plan.thresholds.isEmpty {
        let rows = plan.thresholds.map {
            "<tr><td>\(escape($0.label))</td><td>\($0.lengthMm) mm</td><td>\($0.widthMm) mm</td></tr>"
        }.joined()
        extra += """
        <div class="card"><header><h2 class="text-base font-semibold">Przejścia / listwy progowe</h2></header><section>
        <div class="table-container app-table-wrap"><table class="table"><thead><tr><th>Element</th><th>Długość</th><th>Szerokość</th></tr></thead><tbody>\(rows)</tbody></table></div>
        <p class="text-sm text-muted-foreground">Deska urywa się na progu. Szczelinę dylatacyjną zasłania listwa.</p>
        </section></div>
        """
    }
    if !plan.warnings.isEmpty {
        let items = plan.warnings.map { "<li>\(escape($0.messagePl))</li>" }.joined()
        extra += """
        <div class="card"><header><h2 class="text-base font-semibold">Uwagi majstra</h2></header><section>
        <ul class="app-stack app-stack--tight">\(items)</ul></section></div>
        """
    }
    let steps = plan.rowsInstructionPl.map { "<li>\(escape($0))</li>" }.joined()
    let packs = plan.bom.packs.map { "<tr><th>Paczek</th><td>\($0)</td></tr>" } ?? ""
    let angle = plan.angleDeg == 0 ? "" : "<tr><th>Kąt</th><td>\(plan.angleDeg)°</td></tr>"
    let split = plan.splitAtMm.map { "<tr><th>Podziałka</th><td>\($0) mm</td></tr>" } ?? ""
    let strips = plan.thresholds.isEmpty ? "" : "<tr><th>Listwy progowe</th><td>\(plan.thresholds.count)</td></tr>"
    return """
    <section class="app-stack" id="plan-result">
      <div class="card">
        <header>
          <h2 class="text-base font-semibold">Podgląd instalacji</h2>
          <p class="text-sm text-muted-foreground">\(escape(plan.rationalePl))</p>
        </header>
        <section class="pln-stage">\(svg)</section>
      </div>
      <div class="card">
        <header><h2 class="text-base font-semibold">Ilość</h2></header>
        <section>
          <div class="table-container app-table-wrap">
            <table class="table"><tbody>
              <tr><th>Sztuki na podłodze</th><td>\(plan.bom.pieces)</td></tr>
              <tr><th>Desek / płytek do kupienia</th><td>\(plan.bom.fullBoards)</td></tr>
              \(packs)
              <tr><th>Pole netto</th><td>\(net) m²</td></tr>
              <tr><th>Odpad</th><td>\(escape(plan.bom.wastePct))%</td></tr>
              <tr><th>Dylatacja</th><td>\(plan.gapMm) mm</td></tr>
              \(angle)\(split)\(strips)
            </tbody></table>
          </div>
        </section>
      </div>
      \(extra)
      <div class="card">
        <header><h2 class="text-base font-semibold">Kolejność ułożenia</h2></header>
        <section><ol class="app-stack app-stack--tight">\(steps)</ol></section>
      </div>
    </section>
    """
}

func errorFragment(_ message: String) -> String {
    """
    <section class="app-stack" id="plan-result">
      <div class="card">
        <header>
          <h2 class="text-base font-semibold">Nie da się rozłożyć</h2>
          <p class="text-sm text-muted-foreground">\(escape(message))</p>
        </header>
      </div>
    </section>
    """
}

func netM2(_ areaMm2: Int) -> String {
    String(format: "%.3f", Double(areaMm2) / 1_000_000.0)
}

private func field(_ id: String, _ label: String, _ value: String, placeholder: String? = nil) -> String {
    let ph = placeholder.map { " placeholder=\"\(attr($0))\"" } ?? ""
    return """
    <label class="app-stack app-stack--tight" for="\(id)">
      <span class="text-sm font-medium">\(escape(label))</span>
      <input id="\(id)" class="input" name="\(id)" value="\(attr(value))"\(ph)>
    </label>
    """
}

private func area(_ id: String, _ label: String, _ value: String, _ rows: Int) -> String {
    """
    <label class="app-stack app-stack--tight" for="\(id)">
      <span class="text-sm font-medium">\(escape(label))</span>
      <textarea id="\(id)" class="input" name="\(id)" rows="\(rows)">\(escape(value))</textarea>
    </label>
    """
}

private func navItem(label: String, href: String, icon: String, key: String, active: Bool) -> String {
    let current = active ? " aria-current=\"page\"" : ""
    let cls = active ? " app-nav-link--active" : ""
    return """
    <li><a class="app-nav-link\(cls)" href="\(attr(href))" data-nav-key="\(attr(key))"\(current) data-no-htmx="true">
      <span class="app-nav-link__icon" aria-hidden="true">\(icon)</span>
      <span class="app-nav-link__label">\(escape(label))</span>
    </a></li>
    """
}

private func fileUpload(id: String, action: String, maxBytes: Int) -> String {
    """
    <form id="\(id)" method="post" action="\(attr(action))" enctype="multipart/form-data" class="app-stack app-stack--sm" data-app-file-upload hx-post="\(attr(action))" hx-encoding="multipart/form-data" hx-target="#plan-panel" hx-swap="innerHTML" x-data="{ dragover: false, uploading: false, progress: 0 }">
      <div class="app-stack app-stack--sm" data-app-file-upload-field data-max-bytes="\(maxBytes)" data-accept=".usdz,model/vnd.usdz+zip" data-label-too-large="Plik jest za duży: {file}." data-label-wrong-type="To nie jest USDZ: {file}." data-label-empty="Wybierz skan RoomPlan." data-label-confirm="" data-remove-label="Usuń">
        <label class="app-dropzone" for="\(id)-input" tabindex="0" data-app-file-dropzone x-bind:data-dragover="dragover ? 'true' : null" x-on:dragover.prevent="dragover = true" x-on:dragleave="dragover = false" x-on:drop.prevent="dragover = false" x-on:keydown.enter.prevent="$refs.input.click()" x-on:keydown.space.prevent="$refs.input.click()">
          <svg class="lucide lucide-file-up text-primary" xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z" /><path d="M14 2v5a1 1 0 0 0 1 1h5" /><path d="M12 12v6" /><path d="m15 15-3-3-3 3" /></svg>
          <span class="font-semibold whitespace-normal">Wybierz skan USDZ</span>
          <span class="text-sm text-muted-foreground">Upuść plik RoomPlan albo wybierz z iPhone'a</span>
          <input id="\(id)-input" class="sr-only" type="file" name="scan" accept=".usdz,model/vnd.usdz+zip" required data-app-file-input x-ref="input" aria-describedby="\(id)-help">
        </label>
        <p class="text-sm text-muted-foreground" id="\(id)-help">Drzwi stają się odcięciem na progu (listwa).</p>
        <ul class="app-stack app-stack--tight" data-app-file-list aria-live="polite"></ul>
      </div>
      <div class="app-stack app-stack--tight" data-app-file-progress hidden>
        <progress class="app-progress w-full" max="100" value="0" data-app-file-progress-bar></progress>
        <span class="text-sm text-muted-foreground" data-app-file-progress-label>0%</span>
      </div>
      <p class="text-sm" role="status" aria-live="polite" data-app-file-status></p>
      <button class="btn w-full" data-variant="primary" data-size="lg" type="submit" data-app-file-submit>
        <span>Wczytaj skan</span>
      </button>
    </form>
    """
}

private let headAssets = """
<link rel="stylesheet" href="/static/platform/basecoat-factory.min.css">
<style type="text/tailwindcss">
@layer theme { @import "tailwindcss/theme"; }
@layer utilities { @import "tailwindcss/utilities"; }
@custom-variant dark (&:is(html.dark *));
</style>
<script src="/static/platform/tailwind.min.js"></script>
<script src="/static/platform/basecoat-js.min.js" defer></script>
<meta name="htmx-config" content='{"noSwap":[204,304,"4xx","5xx"]}'>
<script src="/static/platform/htmx.min.js"></script>
<script src="/static/platform/alpine.min.js" defer></script>
<script>
  document.addEventListener('htmx:config:request', function (event) {
    var request = event.detail && event.detail.ctx && event.detail.ctx.request;
    if (request) { request.credentials = 'same-origin'; }
  });
  document.addEventListener('htmx:after:swap', function (event) {
    var ctx = event.detail && event.detail.ctx;
    var elt = ctx && (ctx.target || ctx.sourceElement);
    if (!elt || typeof window.Alpine === 'undefined' || !window.Alpine.initTree) return;
    window.Alpine.initTree(elt);
  });
</script>
\(fileUploadBoot)
"""

private let themeLocale = """
<div class="app-cluster app-cluster--center" data-platform-theme-locale>
  <button type="button" class="btn flex items-center justify-center" data-variant="ghost" data-size="icon-sm" data-theme-toggle data-tooltip="Toggle theme" data-side="bottom" data-align="end" aria-label="Toggle theme">
    <svg class="lucide lucide-sun icon-themed theme-toggle-icon theme-toggle-icon--light" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path d="M12 2v2" /><path d="M12 20v2" /><path d="m4.93 4.93 1.41 1.41" /><path d="m17.66 17.66 1.41 1.41" /><path d="M2 12h2" /><path d="M20 12h2" /><path d="m6.34 17.66-1.41 1.41" /><path d="m19.07 4.93-1.41 1.41" /></svg>
    <svg class="lucide lucide-moon icon-themed theme-toggle-icon theme-toggle-icon--dark" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401" /></svg>
  </button>
</div>
"""

private let themeBoot = """
<script>
(() => {
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const validModes = new Set(['light', 'dark', 'auto']);
  let mode = 'auto';
  try { const stored = localStorage.getItem('themeMode'); if (validModes.has(stored)) mode = stored; } catch (_) {}
  const isDark = () => mode === 'dark' || (mode === 'auto' && media.matches);
  const apply = (value, persist = true) => {
    if (value === 'toggle') mode = isDark() ? 'light' : 'dark';
    else mode = validModes.has(value) ? value : 'auto';
    document.documentElement.classList.toggle('dark', isDark());
    document.documentElement.dataset.theme = isDark() ? 'dark' : 'light';
    if (persist) { try { localStorage.setItem('themeMode', mode); } catch (_) {} }
  };
  window.appTheme = { get mode() { return mode; }, set: (value) => apply(value), toggle: () => apply(isDark() ? 'light' : 'dark'), refresh: () => {} };
  apply(mode, false);
  document.addEventListener('click', (event) => {
    const control = event.target.closest?.('[data-theme-toggle]');
    if (!control) return;
    event.preventDefault();
    window.appTheme.toggle();
  });
})();
</script>
"""

private let shellBoot = """
<script>
(() => {
  if (window.__appShellBooted) return;
  window.__appShellBooted = true;
  const getSidebar = (id = 'sidebar') => {
    const sidebar = document.getElementById(id) || document.querySelector('.sidebar');
    return sidebar && typeof sidebar.toggle === 'function' ? sidebar : null;
  };
  document.addEventListener('click', (event) => {
    const sidebarToggle = event.target.closest?.('[data-sidebar-toggle]');
    if (!sidebarToggle) return;
    event.preventDefault();
    getSidebar(sidebarToggle.dataset.sidebarToggle || 'sidebar')?.toggle();
  });
  const initBasecoat = () => { if (window.basecoat && typeof window.basecoat.initAll === 'function') window.basecoat.initAll(); };
  document.addEventListener('DOMContentLoaded', initBasecoat);
  document.addEventListener('htmx:after:swap', initBasecoat);
  if (document.readyState !== 'loading') initBasecoat();
})();
</script>
"""

private let fileUploadBoot = """
<script>
(() => {
  if (window.__appFileUploadBooted) return;
  window.__appFileUploadBooted = true;
  const formatBytes = (bytes) => {
    if (!Number.isFinite(bytes)) return '';
    const units = ['B', 'KiB', 'MiB', 'GiB'];
    let value = bytes; let unit = 0;
    while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit += 1; }
    return `${value >= 10 || unit === 0 ? Math.round(value) : value.toFixed(1)} ${units[unit]}`;
  };
  const accepts = (file, raw) => {
    const tokens = String(raw || '').split(',').map((part) => part.trim().toLowerCase()).filter(Boolean);
    if (!tokens.length) return true;
    const name = String(file.name || '').toLowerCase();
    const type = String(file.type || '').toLowerCase();
    return tokens.some((token) => token.startsWith('.') ? name.endsWith(token) : token.endsWith('/*') ? type.startsWith(token.slice(0, -1)) : type === token);
  };
  const message = (template, values) => Object.entries(values).reduce((text, [key, value]) => text.replaceAll(`{${key}}`, String(value)), String(template || ''));
  const init = (field) => {
    if (!field || field.dataset.appFileUploadReady === 'true') return;
    field.dataset.appFileUploadReady = 'true';
    const form = field.closest('form');
    if (!form) return;
    const input = field.querySelector('[data-app-file-input]');
    const dropzone = field.querySelector('[data-app-file-dropzone]');
    const list = field.querySelector('[data-app-file-list]');
    const status = form.querySelector('[data-app-file-status]');
    const submit = form.querySelector('[data-app-file-submit]');
    if (!input) return;
    const setStatus = (text, state = '') => {
      if (!status) return;
      status.textContent = text || '';
      if (state) status.dataset.state = state; else delete status.dataset.state;
    };
    const setFiles = (files) => {
      const transfer = new DataTransfer();
      files.forEach((file) => transfer.items.add(file));
      input.files = transfer.files;
    };
    const render = () => {
      const files = Array.from(input.files || []);
      if (list) {
        list.replaceChildren(...files.map((file, index) => {
          const item = document.createElement('li');
          item.className = 'app-cluster app-cluster--between text-sm';
          const label = document.createElement('span');
          label.className = 'min-w-0 break-words';
          label.textContent = `${file.name} · ${formatBytes(file.size)}`;
          const remove = document.createElement('button');
          remove.type = 'button';
          remove.className = 'btn';
          remove.dataset.variant = 'ghost';
          remove.dataset.size = 'sm';
          remove.textContent = field.dataset.removeLabel || 'Remove';
          remove.addEventListener('click', () => { setFiles(files.filter((_file, i) => i !== index)); render(); });
          item.append(label, remove);
          return item;
        }));
      }
      if (submit) submit.disabled = input.required && files.length === 0;
      setStatus('');
    };
    input.addEventListener('change', render);
    if (dropzone) {
      dropzone.addEventListener('drop', (event) => {
        if (!event.dataTransfer) return;
        setFiles(Array.from(event.dataTransfer.files));
        render();
      });
    }
    form.addEventListener('submit', (event) => {
      const files = Array.from(input.files || []);
      if (!files.length && input.required) { event.preventDefault(); setStatus(field.dataset.labelEmpty, 'error'); return; }
      const max = Number.parseInt(field.dataset.maxBytes || '', 10);
      const oversized = Number.isFinite(max) ? files.filter((file) => file.size > max) : [];
      if (oversized.length) { event.preventDefault(); setStatus(message(field.dataset.labelTooLarge, { file: oversized.map((f) => f.name).join(', ') }), 'error'); return; }
      const wrong = files.filter((file) => !accepts(file, field.dataset.accept));
      if (wrong.length) { event.preventDefault(); setStatus(message(field.dataset.labelWrongType, { file: wrong.map((f) => f.name).join(', ') }), 'error'); return; }
    });
    render();
  };
  const initAll = (root = document) => root.querySelectorAll?.('[data-app-file-upload-field]').forEach(init);
  document.addEventListener('DOMContentLoaded', () => initAll());
  document.addEventListener('htmx:after:swap', (event) => {
    const ctx = event.detail && event.detail.ctx;
    initAll((ctx && (ctx.target || ctx.sourceElement)) || document);
  });
  if (document.readyState !== 'loading') initAll();
})();
</script>
"""
