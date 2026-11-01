<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="html" encoding="UTF-8" indent="yes" doctype-system="about:legacy-compat"/>
    <xsl:strip-space elements="*"/>

    <xsl:key name="loan-by-status" match="livre" use="@rendue"/>

    <xsl:variable name="total"    select="count(/biblio/etudiant/livre)"/>
    <xsl:variable name="returned" select="count(key('loan-by-status', 'oui'))"/>
    <xsl:variable name="pending"  select="$total - $returned"/>
    <xsl:variable name="students" select="count(/biblio/etudiant)"/>
    <xsl:variable name="rate">
        <xsl:choose>
            <xsl:when test="$total &gt; 0"><xsl:value-of select="round(100 * $returned div $total)"/></xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/">
        <html lang="fr">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <meta name="color-scheme" content="light dark"/>
                <meta name="description" content="Suivi des emprunts de la bibliothèque"/>
                <title>Emprunts de la bibliothèque</title>
                <style><![CDATA[
                    /* ---------- Design tokens ---------- */
                    :root {
                        color-scheme: light dark;
                        --canvas: #F3F4F7;
                        --surface: #FFFFFF;
                        --head: #F9FAFC;
                        --row-hover: #F5F6FB;
                        --ink: #12151C;
                        --muted: #5A6172;
                        --line: #E3E6EC;
                        --accent: #2F4CDD;
                        --ok: #0B7A62;
                        --ok-soft: #DDF4EC;
                        --warn: #9A5106;
                        --warn-soft: #FDEFD9;
                        --radius-panel: 14px;
                        --radius-control: 10px;
                        --ease: cubic-bezier(.2, .7, .2, 1);
                        --dur-fast: 140ms;
                        --dur-base: 240ms;
                        --stagger: 32ms;
                        --font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                    }

                    @media (prefers-color-scheme: dark) {
                        :root {
                            --canvas: #0D0F14;
                            --surface: #151821;
                            --head: #12151D;
                            --row-hover: #1A1E29;
                            --ink: #ECEEF3;
                            --muted: #9AA1B2;
                            --line: #262A36;
                            --accent: #93A4FF;
                            --ok: #5FD3B2;
                            --ok-soft: #10312A;
                            --warn: #F2B060;
                            --warn-soft: #37270F;
                        }
                    }

                    /* ---------- Base ---------- */
                    *, *::before, *::after { box-sizing: border-box; }
                    [hidden] { display: none !important; }

                    body {
                        margin: 0;
                        min-height: 100dvh;
                        background: var(--canvas);
                        color: var(--ink);
                        font: 400 1rem/1.5 var(--font);
                        -webkit-font-smoothing: antialiased;
                    }

                    :focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

                    .sr-only {
                        position: absolute;
                        inline-size: 1px;
                        block-size: 1px;
                        overflow: hidden;
                        clip-path: inset(50%);
                        white-space: nowrap;
                    }

                    .shell {
                        max-inline-size: 1040px;
                        margin-inline: auto;
                        padding: clamp(20px, 5vw, 56px) clamp(16px, 4vw, 32px);
                    }

                    /* ---------- Masthead ---------- */
                    .masthead {
                        display: grid;
                        grid-template-columns: 1fr minmax(220px, 280px);
                        gap: 24px 48px;
                        align-items: end;
                        margin-block-end: 28px;
                    }

                    h1 {
                        margin: 0;
                        font-size: clamp(1.5rem, 1.1rem + 1.4vw, 2rem);
                        font-weight: 650;
                        letter-spacing: -0.025em;
                        line-height: 1.15;
                    }

                    .lede { margin: 6px 0 0; color: var(--muted); }

                    .meter-head {
                        display: flex;
                        justify-content: space-between;
                        font-size: .875rem;
                        color: var(--muted);
                    }

                    .meter-value { color: var(--ink); font-weight: 650; font-variant-numeric: tabular-nums; }

                    .meter {
                        block-size: 6px;
                        margin-block: 8px;
                        border-radius: 999px;
                        background: var(--line);
                        overflow: hidden;
                    }

                    .meter-fill {
                        display: block;
                        block-size: 100%;
                        inline-size: calc(var(--value) * 1%);
                        border-radius: inherit;
                        background: var(--accent);
                        animation: meter-in 900ms var(--ease) 200ms backwards;
                    }

                    .meter-note { margin: 0; font-size: .8125rem; color: var(--muted); }

                    /* ---------- Panel and toolbar ---------- */
                    .panel {
                        background: var(--surface);
                        border: 1px solid var(--line);
                        border-radius: var(--radius-panel);
                        box-shadow: 0 1px 2px rgba(16, 24, 40, .05);
                        overflow: hidden;
                    }

                    .toolbar {
                        display: flex;
                        flex-wrap: wrap;
                        gap: 12px;
                        justify-content: space-between;
                        padding: 14px 16px;
                        border-block-end: 1px solid var(--line);
                    }

                    .search {
                        inline-size: min(100%, 320px);
                        padding: 9px 12px 9px 38px;
                        border: 1px solid var(--line);
                        border-radius: var(--radius-control);
                        background: var(--surface) no-repeat 12px center / 16px
                            url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='none' stroke='%238A91A0' stroke-width='1.8' stroke-linecap='round'%3E%3Ccircle cx='9' cy='9' r='5.5'/%3E%3Cpath d='M13.5 13.5L17 17'/%3E%3C/svg%3E");
                        color: var(--ink);
                        font: inherit;
                        font-size: .9375rem;
                        transition: border-color var(--dur-fast), box-shadow var(--dur-fast);
                    }

                    .search::placeholder { color: var(--muted); }

                    .search:focus-visible {
                        outline: none;
                        border-color: var(--accent);
                        box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 25%, transparent);
                    }

                    .segments {
                        display: inline-flex;
                        gap: 2px;
                        padding: 3px;
                        border: 1px solid var(--line);
                        border-radius: var(--radius-control);
                        background: var(--head);
                    }

                    .segment {
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        padding: 6px 12px;
                        border: 0;
                        border-radius: 7px;
                        background: transparent;
                        color: var(--muted);
                        font: inherit;
                        font-size: .875rem;
                        font-weight: 550;
                        cursor: pointer;
                        transition: background var(--dur-fast), color var(--dur-fast), box-shadow var(--dur-fast);
                    }

                    .segment:hover { color: var(--ink); }

                    .segment[aria-pressed="true"] {
                        background: var(--surface);
                        color: var(--ink);
                        box-shadow: 0 1px 2px rgba(16, 24, 40, .14), 0 0 0 1px var(--line);
                    }

                    .segment-count { font-variant-numeric: tabular-nums; font-weight: 450; opacity: .75; }

                    /* ---------- Table ---------- */
                    .table-wrap { max-block-size: min(70vh, 640px); overflow: auto; overscroll-behavior: contain; }

                    table {
                        inline-size: 100%;
                        border-collapse: separate;
                        border-spacing: 0;
                        font-size: .9375rem;
                    }

                    thead th {
                        position: sticky;
                        top: 0;
                        z-index: 1;
                        padding: 0;
                        background: var(--head);
                        border-block-end: 1px solid var(--line);
                        color: var(--muted);
                        font-size: .8125rem;
                        font-weight: 600;
                        text-align: start;
                    }

                    thead th[aria-sort="ascending"],
                    thead th[aria-sort="descending"] { color: var(--ink); }

                    .sort {
                        display: flex;
                        align-items: center;
                        gap: 8px;
                        inline-size: 100%;
                        padding: 12px 16px;
                        border: 0;
                        background: none;
                        color: inherit;
                        font: inherit;
                        text-align: start;
                        cursor: pointer;
                    }

                    .sort:focus-visible { outline-offset: -2px; }

                    .sort::after {
                        content: "";
                        inline-size: .45em;
                        block-size: .45em;
                        border: solid currentColor;
                        border-width: 0 1.6px 1.6px 0;
                        transform: rotate(45deg) translate(-1px, -1px);
                        opacity: 0;
                        transition: opacity var(--dur-fast), transform var(--dur-base) var(--ease);
                    }

                    .sort:hover::after { opacity: .5; }
                    th[aria-sort="descending"] .sort::after { opacity: 1; }
                    th[aria-sort="ascending"] .sort::after {
                        opacity: 1;
                        transform: rotate(-135deg) translate(-1px, -1px);
                    }

                    tbody td {
                        padding: 14px 16px;
                        border-block-end: 1px solid var(--line);
                        background: var(--surface);
                        transition: background var(--dur-fast);
                    }

                    tbody tr:last-child td { border-block-end: 0; }

                    /* Accent rail grows in on hover: no scaling, so text never blurs or reflows. */
                    tbody td:first-child {
                        box-shadow: inset 0 0 0 0 var(--accent);
                        transition: background var(--dur-fast), box-shadow var(--dur-base) var(--ease);
                    }

                    tbody tr:hover td,
                    tbody tr:focus-within td { background: var(--row-hover); }

                    tbody tr:hover td:first-child,
                    tbody tr:focus-within td:first-child { box-shadow: inset 3px 0 0 0 var(--accent); }

                    /* Single orchestrated page-load moment; the script takes over after first interaction. */
                    table:not(.is-live) tbody tr {
                        animation: row-in var(--dur-base) var(--ease) backwards;
                        animation-delay: calc(min(var(--i), 14) * var(--stagger));
                    }

                    .identity { display: inline-flex; align-items: center; gap: 12px; }

                    .avatar {
                        display: inline-grid;
                        place-items: center;
                        inline-size: 30px;
                        block-size: 30px;
                        border-radius: 50%;
                        background: color-mix(in srgb, var(--accent) 12%, var(--surface));
                        color: var(--accent);
                        font-size: .75rem;
                        font-weight: 650;
                        text-transform: uppercase;
                    }

                    .title { font-weight: 600; }
                    .date { color: var(--muted); font-variant-numeric: tabular-nums; }

                    /* ---------- Status badge: colour is never the only signal (filled vs hollow dot + text). ---------- */
                    .badge {
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        padding: 3px 11px 3px 9px;
                        border-radius: 999px;
                        font-size: .8125rem;
                        font-weight: 600;
                    }

                    .badge::before { content: ""; inline-size: 8px; block-size: 8px; border-radius: 50%; background: currentColor; }
                    .badge-ok { background: var(--ok-soft); color: var(--ok); }
                    .badge-pending { background: var(--warn-soft); color: var(--warn); }
                    .badge-pending::before { background: transparent; box-shadow: inset 0 0 0 1.75px currentColor; }

                    /* ---------- Footer and empty states ---------- */
                    .panel-foot {
                        padding: 12px 16px;
                        border-block-start: 1px solid var(--line);
                        color: var(--muted);
                        font-size: .8125rem;
                    }

                    .empty { padding: 48px 16px; text-align: center; color: var(--muted); }
                    .empty p { margin: 0 0 12px; }

                    .link-button {
                        padding: 8px 14px;
                        border: 1px solid var(--line);
                        border-radius: var(--radius-control);
                        background: var(--surface);
                        color: var(--ink);
                        font: inherit;
                        font-size: .875rem;
                        font-weight: 550;
                        cursor: pointer;
                        transition: border-color var(--dur-fast), color var(--dur-fast);
                    }

                    .link-button:hover { border-color: var(--accent); color: var(--accent); }

                    /* ---------- Motion ---------- */
                    @keyframes row-in { from { opacity: 0; transform: translateY(8px); } }
                    @keyframes meter-in { from { inline-size: 0; } }

                    @media (prefers-reduced-motion: reduce) {
                        *, *::before, *::after {
                            animation-duration: .001ms !important;
                            animation-delay: 0ms !important;
                            transition-duration: .001ms !important;
                        }
                    }

                    /* ---------- Small screens: rows become labelled cards ---------- */
                    @media (max-width: 40rem) {
                        .masthead { grid-template-columns: 1fr; }
                        .toolbar { flex-direction: column; }
                        .search { inline-size: 100%; }
                        .segments { display: flex; }
                        .segment { flex: 1; justify-content: center; }

                        thead {
                            position: absolute;
                            inline-size: 1px;
                            block-size: 1px;
                            overflow: hidden;
                            clip-path: inset(50%);
                        }

                        table, tbody { display: block; }

                        tbody tr {
                            display: grid;
                            gap: 2px;
                            padding: 12px 16px;
                            border-block-end: 1px solid var(--line);
                        }

                        tbody tr:last-child { border-block-end: 0; }

                        tbody td,
                        tbody tr:last-child td {
                            display: flex;
                            justify-content: space-between;
                            align-items: center;
                            gap: 16px;
                            padding: 6px 0;
                            border: 0;
                            background: transparent;
                            box-shadow: none !important;
                        }

                        tbody td::before {
                            content: attr(data-label);
                            color: var(--muted);
                            font-size: .8125rem;
                        }
                    }

                    @media print {
                        body { background: #fff; }
                        .toolbar, .panel-foot { display: none; }
                        .table-wrap { max-block-size: none; overflow: visible; }
                        table:not(.is-live) tbody tr { animation: none; }
                    }
                ]]></style>
            </head>
            <body>
                <main class="shell">
                    <header class="masthead">
                        <div>
                            <h1>Emprunts de la bibliothèque</h1>
                            <p class="lede">
                                <xsl:value-of select="$total"/> emprunt<xsl:if test="$total != 1">s</xsl:if>
                                pour <xsl:value-of select="$students"/> étudiant<xsl:if test="$students != 1">s</xsl:if>.
                            </p>
                        </div>
                        <div>
                            <div class="meter-head">
                                <span id="meter-label">Taux de retour</span>
                                <span class="meter-value"><xsl:value-of select="$rate"/>&#160;%</span>
                            </div>
                            <div class="meter" role="progressbar" aria-labelledby="meter-label"
                                 aria-valuemin="0" aria-valuemax="100" aria-valuenow="{$rate}">
                                <span class="meter-fill" style="--value: {$rate}"/>
                            </div>
                            <p class="meter-note"><xsl:value-of select="$returned"/> rendu<xsl:if test="$returned != 1">s</xsl:if> sur <xsl:value-of select="$total"/></p>
                        </div>
                    </header>

                    <xsl:choose>
                        <xsl:when test="$total &gt; 0">
                            <section class="panel" aria-label="Liste des emprunts">
                                <div class="toolbar" id="toolbar" hidden="hidden">
                                    <label class="sr-only" for="q">Rechercher un étudiant ou un livre</label>
                                    <input class="search" id="q" type="search" autocomplete="off"
                                           placeholder="Rechercher un étudiant ou un livre"/>
                                    <div class="segments" role="group" aria-label="Filtrer par statut">
                                        <xsl:call-template name="segment">
                                            <xsl:with-param name="value" select="'all'"/>
                                            <xsl:with-param name="label" select="'Tous'"/>
                                            <xsl:with-param name="count" select="$total"/>
                                        </xsl:call-template>
                                        <xsl:call-template name="segment">
                                            <xsl:with-param name="value" select="'oui'"/>
                                            <xsl:with-param name="label" select="'Rendus'"/>
                                            <xsl:with-param name="count" select="$returned"/>
                                        </xsl:call-template>
                                        <xsl:call-template name="segment">
                                            <xsl:with-param name="value" select="'non'"/>
                                            <xsl:with-param name="label" select="'En cours'"/>
                                            <xsl:with-param name="count" select="$pending"/>
                                        </xsl:call-template>
                                    </div>
                                </div>

                                <div class="table-wrap" role="region" aria-label="Tableau des emprunts" tabindex="0">
                                    <table id="emprunts" role="table">
                                        <thead role="rowgroup">
                                            <tr role="row">
                                                <xsl:call-template name="sortable-th"><xsl:with-param name="label" select="'Nom'"/></xsl:call-template>
                                                <xsl:call-template name="sortable-th"><xsl:with-param name="label" select="'Prénom'"/></xsl:call-template>
                                                <xsl:call-template name="sortable-th"><xsl:with-param name="label" select="'Livre'"/></xsl:call-template>
                                                <xsl:call-template name="sortable-th">
                                                    <xsl:with-param name="label" select="'Date d’emprunt'"/>
                                                    <xsl:with-param name="type" select="'date'"/>
                                                </xsl:call-template>
                                                <xsl:call-template name="sortable-th"><xsl:with-param name="label" select="'Statut'"/></xsl:call-template>
                                            </tr>
                                        </thead>
                                        <tbody role="rowgroup">
                                            <xsl:apply-templates select="/biblio/etudiant/livre"/>
                                        </tbody>
                                    </table>
                                </div>

                                <div class="empty" id="empty" hidden="hidden">
                                    <p>Aucun emprunt ne correspond à votre recherche.</p>
                                    <button class="link-button" id="reset" type="button">Réinitialiser les filtres</button>
                                </div>

                                <p class="panel-foot" id="count" aria-live="polite">
                                    <xsl:value-of select="$total"/> sur <xsl:value-of select="$total"/> emprunt<xsl:if test="$total != 1">s</xsl:if>
                                </p>
                            </section>
                        </xsl:when>
                        <xsl:otherwise>
                            <section class="panel empty">
                                <p>Aucun emprunt enregistré pour le moment.</p>
                            </section>
                        </xsl:otherwise>
                    </xsl:choose>
                </main>

                <script><![CDATA[
                    (function () {
                        'use strict';

                        var table = document.getElementById('emprunts');
                        if (!table) { return; }

                        var MAX_ANIMATED_ROWS = 12;
                        var STAGGER_MS = 18;
                        var DURATION_MS = 220;
                        var EASING = 'cubic-bezier(.2, .7, .2, 1)';

                        var tbody = table.tBodies[0];
                        var original = Array.prototype.slice.call(tbody.rows);
                        var headers = Array.prototype.slice.call(table.querySelectorAll('thead th'));
                        var segments = Array.prototype.slice.call(document.querySelectorAll('.segment'));
                        var input = document.getElementById('q');
                        var counter = document.getElementById('count');
                        var emptyState = document.getElementById('empty');
                        var resetButton = document.getElementById('reset');
                        var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

                        var state = { query: '', status: 'all', column: -1, direction: 1 };

                        // Accent- and case-insensitive matching: "etienne" finds "Étienne".
                        function fold(text) {
                            return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
                        }

                        function parseDate(value) {
                            var iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
                            if (iso) { return Date.UTC(+iso[1], iso[2] - 1, +iso[3]); }
                            var fr = /^(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{4})/.exec(value);
                            return fr ? Date.UTC(+fr[3], fr[2] - 1, +fr[1]) : NaN;
                        }

                        function compare(a, b, type) {
                            if (type === 'date') {
                                var dateA = parseDate(a);
                                var dateB = parseDate(b);
                                if (!isNaN(dateA) && !isNaN(dateB)) { return dateA - dateB; }
                            }
                            return a.localeCompare(b, 'fr', { sensitivity: 'base', numeric: true });
                        }

                        function cellText(row, index) { return row.cells[index].textContent.trim(); }

                        function matches(row) {
                            var statusOk = state.status === 'all' || row.dataset.rendue === state.status;
                            var queryOk = !state.query || row.dataset.search.indexOf(state.query) !== -1;
                            return statusOk && queryOk;
                        }

                        // Motion that answers a user action: a short staggered re-entry of the visible rows.
                        function replay(visibleRows) {
                            if (reduceMotion.matches || !visibleRows.length || !visibleRows[0].animate) { return; }
                            visibleRows.slice(0, MAX_ANIMATED_ROWS).forEach(function (row, index) {
                                row.animate(
                                    [{ opacity: 0, transform: 'translateY(6px)' }, { opacity: 1, transform: 'none' }],
                                    { duration: DURATION_MS, delay: index * STAGGER_MS, easing: EASING, fill: 'backwards' }
                                );
                            });
                        }

                        function render(animate) {
                            // Hand over from the CSS load animation, which would otherwise restart on un-hiding.
                            table.classList.add('is-live');

                            var ordered = original;
                            if (state.column >= 0) {
                                var type = headers[state.column].dataset.type;
                                ordered = original.slice().sort(function (a, b) {
                                    return state.direction * compare(cellText(a, state.column), cellText(b, state.column), type);
                                });
                            }

                            var visible = [];
                            ordered.forEach(function (row) {
                                var show = matches(row);
                                row.hidden = !show;
                                tbody.appendChild(row);
                                if (show) { visible.push(row); }
                            });

                            counter.textContent = visible.length + ' sur ' + original.length +
                                ' emprunt' + (original.length > 1 ? 's' : '');
                            emptyState.hidden = visible.length > 0;
                            if (animate) { replay(visible); }
                        }

                        function setStatus(status) {
                            state.status = status;
                            segments.forEach(function (segment) {
                                segment.setAttribute('aria-pressed', String(segment.dataset.filter === status));
                            });
                        }

                        original.forEach(function (row) { row.dataset.search = fold(row.textContent); });

                        headers.forEach(function (th, index) {
                            var button = th.querySelector('.sort');
                            if (!button) { return; }
                            button.addEventListener('click', function () {
                                state.direction = state.column === index ? -state.direction : 1;
                                state.column = index;
                                headers.forEach(function (header) { header.setAttribute('aria-sort', 'none'); });
                                th.setAttribute('aria-sort', state.direction === 1 ? 'ascending' : 'descending');
                                render(true);
                            });
                        });

                        segments.forEach(function (segment) {
                            segment.addEventListener('click', function () {
                                setStatus(segment.dataset.filter);
                                render(true);
                            });
                        });

                        // No replay while typing: re-animating on every keystroke is noise.
                        input.addEventListener('input', function () {
                            state.query = fold(input.value.trim());
                            render(false);
                        });

                        resetButton.addEventListener('click', function () {
                            input.value = '';
                            state.query = '';
                            setStatus('all');
                            render(true);
                            input.focus();
                        });

                        document.getElementById('toolbar').hidden = false;
                    }());
                ]]></script>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="livre">
        <xsl:variable name="status">
            <xsl:choose>
                <xsl:when test="@rendue = 'oui'">oui</xsl:when>
                <xsl:otherwise>non</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <tr role="row" data-rendue="{$status}" style="--i: {position()}">
            <td role="cell" data-label="Nom">
                <span class="identity">
                    <span class="avatar" aria-hidden="true"><xsl:value-of select="substring(../@prenom, 1, 1)"/><xsl:value-of select="substring(../@nom, 1, 1)"/></span>
                    <xsl:value-of select="../@nom"/>
                </span>
            </td>
            <td role="cell" data-label="Prénom"><xsl:value-of select="../@prenom"/></td>
            <td role="cell" data-label="Livre"><span class="title"><xsl:value-of select="@titre"/></span></td>
            <td role="cell" data-label="Date d’emprunt"><span class="date"><xsl:value-of select="@dateempre"/></span></td>
            <td role="cell" data-label="Statut">
                <xsl:choose>
                    <xsl:when test="$status = 'oui'"><span class="badge badge-ok">Rendu</span></xsl:when>
                    <xsl:otherwise><span class="badge badge-pending">En cours</span></xsl:otherwise>
                </xsl:choose>
            </td>
        </tr>
    </xsl:template>

    <xsl:template name="sortable-th">
        <xsl:param name="label"/>
        <xsl:param name="type" select="'text'"/>
        <th role="columnheader" scope="col" aria-sort="none" data-type="{$type}">
            <button class="sort" type="button"><xsl:value-of select="$label"/></button>
        </th>
    </xsl:template>

    <xsl:template name="segment">
        <xsl:param name="value"/>
        <xsl:param name="label"/>
        <xsl:param name="count"/>
        <button class="segment" type="button" data-filter="{$value}" aria-pressed="{$value = 'all'}">
            <xsl:value-of select="$label"/>
            <span class="segment-count"><xsl:value-of select="$count"/></span>
        </button>
    </xsl:template>

</xsl:stylesheet>
