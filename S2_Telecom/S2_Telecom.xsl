<?xml version="1.0" encoding="UTF-8"?>
<!--
  S2_Telecom.xsl : renders S2_Telecom.xml (operateur > client > abonnement > facture)
  as an interactive master-detail ledger.

  Design notes
  - XSLT 1.0 only: runs in any engine (browser, xsltproc, lxml, Saxon, polyfill).
  - DTD defaults are mirrored here because browsers never load the DTD:
    a missing @reglee means "oui" (paid), a missing @type means "GSM".
  - Structure comes from XSLT, presentation from CSS, behaviour from a small
    progressive-enhancement script. With JavaScript off, the data is still readable.
  - Currency is centralised in $currency below.
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="html" encoding="UTF-8" indent="yes" doctype-system="about:legacy-compat"/>
    <xsl:strip-space elements="*"/>

    <!-- French number format: 1 236,49 (non-breaking space as thousands separator). -->
    <xsl:decimal-format name="fr" decimal-separator="," grouping-separator="&#160;"/>

    <!-- ========================================================= Settings -->
    <xsl:variable name="currency" select="'DH'"/>
    <!-- Five characters per month, so a month is a fixed-width slice. -->
    <xsl:variable name="months" select="'janv.févr.mars avr. mai  juin juil.août sept.oct. nov. déc. '"/>

    <!-- ========================================================= Aggregates -->
    <xsl:variable name="clients"     select="/operateur/client"/>
    <xsl:variable name="invoices"    select="$clients/abonnement/facture"/>
    <xsl:variable name="unpaid-list" select="$invoices[@reglee = 'non']"/>

    <xsl:variable name="nb-clients"  select="count($clients)"/>
    <xsl:variable name="nb-subs"     select="count($clients/abonnement)"/>
    <xsl:variable name="nb-invoices" select="count($invoices)"/>
    <xsl:variable name="nb-unpaid"   select="count($unpaid-list)"/>
    <xsl:variable name="nb-paid"     select="$nb-invoices - $nb-unpaid"/>
    <xsl:variable name="nb-debtors"  select="count($clients[abonnement/facture/@reglee = 'non'])"/>

    <xsl:variable name="billed" select="sum($invoices/@montant)"/>
    <xsl:variable name="unpaid" select="sum($unpaid-list/@montant)"/>
    <xsl:variable name="paid"   select="$billed - $unpaid"/>

    <xsl:variable name="paid-share">
        <xsl:choose>
            <xsl:when test="$billed &gt; 0"><xsl:value-of select="round(100 * $paid div $billed)"/></xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="unpaid-share" select="100 - $paid-share"/>

    <!-- ========================================================= Page shell -->
    <xsl:template match="/">
        <html lang="fr">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <meta name="color-scheme" content="light dark"/>
                <meta name="description" content="Clients, abonnements et facturation de l’opérateur"/>
                <title>Clients et facturation</title>
                <style><![CDATA[
                    /* ---------- Design tokens ---------- */
                    :root {
                        color-scheme: light dark;
                        --canvas: #EEF1F5;
                        --surface: #FFFFFF;
                        --head: #F7F9FB;
                        --detail: #F7F9FC;
                        --row-hover: #F3F7FF;
                        --ink: #0F1B2D;
                        --muted: #566074;
                        --line: #DCE2EA;
                        --accent: #0B5FFF;
                        --accent-soft: #E6EEFF;
                        --paid: #0A7468;
                        --paid-soft: #DCF3EF;
                        --due: #B3391A;
                        --due-soft: #FDE8E1;
                        --radius-panel: 14px;
                        --radius-control: 10px;
                        --ease: cubic-bezier(.2, .7, .2, 1);
                        --dur-fast: 140ms;
                        --dur-base: 240ms;
                        --dur-slow: 320ms;
                        --stagger: 32ms;
                        --font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                        --icon-gsm: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Crect x='3' y='13' width='4.5' height='8' rx='1.2'/%3E%3Crect x='9.75' y='8' width='4.5' height='13' rx='1.2'/%3E%3Crect x='16.5' y='3' width='4.5' height='18' rx='1.2'/%3E%3C/svg%3E");
                        --icon-fixe: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z'/%3E%3C/svg%3E");
                    }

                    @media (prefers-color-scheme: dark) {
                        :root {
                            --canvas: #0A0F18;
                            --surface: #111826;
                            --head: #0E1521;
                            --detail: #0E1522;
                            --row-hover: #151F33;
                            --ink: #E8EDF5;
                            --muted: #93A0B5;
                            --line: #222C3D;
                            --accent: #6EA0FF;
                            --accent-soft: #172746;
                            --paid: #4FD1BD;
                            --paid-soft: #0F2E2B;
                            --due: #FF9A7A;
                            --due-soft: #381C14;
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
                        max-inline-size: 1120px;
                        margin-inline: auto;
                        padding: clamp(20px, 5vw, 56px) clamp(16px, 4vw, 32px);
                    }

                    /* ---------- Masthead and recovery summary ---------- */
                    .masthead {
                        display: grid;
                        grid-template-columns: minmax(0, 1fr) minmax(300px, 420px);
                        gap: 28px 64px;
                        align-items: end;
                        margin-block-end: 32px;
                    }

                    h1 {
                        margin: 0;
                        font-size: clamp(1.5rem, 1.1rem + 1.4vw, 2rem);
                        font-weight: 650;
                        letter-spacing: -0.025em;
                        line-height: 1.15;
                    }

                    .lede { margin: 6px 0 0; color: var(--muted); }

                    .recovery-label { margin: 0; font-size: .875rem; color: var(--muted); }

                    .recovery-amount {
                        margin: 2px 0 0;
                        font-size: clamp(2rem, 1.3rem + 3vw, 3.25rem);
                        font-weight: 650;
                        letter-spacing: -0.035em;
                        line-height: 1.05;
                        font-variant-numeric: tabular-nums;
                    }

                    .currency { margin-inline-start: .35em; font-size: .4em; font-weight: 600; letter-spacing: 0; color: var(--muted); }
                    .recovery-note { margin: 6px 0 0; font-size: .875rem; color: var(--muted); }

                    .split {
                        display: flex;
                        gap: 3px;
                        block-size: 8px;
                        margin-block: 16px 10px;
                    }

                    .split-seg {
                        flex: var(--share) 1 0;
                        border-radius: 999px;
                        animation: bar-in 900ms var(--ease) backwards;
                    }

                    .split-paid { background: var(--paid); animation-delay: 200ms; }
                    .split-unpaid { background: var(--due); animation-delay: 520ms; }

                    .legend { display: flex; justify-content: space-between; gap: 16px; margin: 0; padding: 0; list-style: none; font-size: .875rem; }
                    .legend li { display: grid; gap: 1px; }
                    .legend-name { display: inline-flex; align-items: center; gap: 8px; font-weight: 600; }
                    .legend-name::before { content: ""; inline-size: 8px; block-size: 8px; border-radius: 50%; background: var(--paid); }
                    .legend-due .legend-name::before { background: var(--due); }
                    .legend-value { font-variant-numeric: tabular-nums; }
                    .legend-sub { color: var(--muted); font-size: .8125rem; }

                    /* ---------- Panel and toolbar ---------- */
                    .panel {
                        background: var(--surface);
                        border: 1px solid var(--line);
                        border-radius: var(--radius-panel);
                        box-shadow: 0 1px 2px rgba(15, 27, 45, .05);
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

                    .filters { display: flex; flex-wrap: wrap; gap: 8px; }

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

                    .segment, .ghost {
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
                        transition: background var(--dur-fast), color var(--dur-fast), box-shadow var(--dur-fast), border-color var(--dur-fast);
                    }

                    .segment:hover, .ghost:hover { color: var(--ink); }

                    .segment[aria-pressed="true"] {
                        background: var(--surface);
                        color: var(--ink);
                        box-shadow: 0 1px 2px rgba(15, 27, 45, .14), 0 0 0 1px var(--line);
                    }

                    .segment-count { font-variant-numeric: tabular-nums; font-weight: 450; opacity: .75; }

                    .ghost { padding: 8px 14px; border: 1px solid var(--line); border-radius: var(--radius-control); background: var(--surface); }
                    .ghost:hover { border-color: var(--accent); color: var(--accent); }
                    .ghost:disabled { opacity: .5; cursor: default; }

                    /* ---------- Ledger table ---------- */
                    .table-wrap { max-block-size: min(72vh, 700px); overflow: auto; overscroll-behavior: contain; }

                    .ledger {
                        inline-size: 100%;
                        border-collapse: separate;
                        border-spacing: 0;
                        font-size: .9375rem;
                    }

                    .ledger thead th {
                        position: sticky;
                        top: 0;
                        z-index: 2;
                        padding: 0;
                        background: var(--head);
                        border-block-end: 1px solid var(--line);
                        color: var(--muted);
                        font-size: .8125rem;
                        font-weight: 600;
                        text-align: start;
                        white-space: nowrap;
                    }

                    .ledger thead th[aria-sort="ascending"],
                    .ledger thead th[aria-sort="descending"] { color: var(--ink); }

                    .th-label { display: block; padding: 12px 16px; }
                    .num { text-align: end !important; font-variant-numeric: tabular-nums; white-space: nowrap; }
                    .num .sort { justify-content: flex-end; }

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
                    th[aria-sort="ascending"] .sort::after { opacity: 1; transform: rotate(-135deg) translate(-1px, -1px); }

                    /* One tbody per client: master row + collapsible detail row. */
                    .client-row { cursor: pointer; }

                    .client-row > * {
                        padding: 12px 16px;
                        background: var(--surface);
                        border-block-end: 1px solid var(--line);
                        text-align: start;
                        font-weight: 400;
                        vertical-align: middle;
                        transition: background var(--dur-fast);
                    }

                    .client-row > th { padding: 0; }

                    /* Accent rail: no scaling, so text never blurs or reflows on hover. */
                    .client-row > :first-child {
                        box-shadow: inset 0 0 0 0 var(--accent);
                        transition: background var(--dur-fast), box-shadow var(--dur-base) var(--ease);
                    }

                    .client-row:hover > *,
                    .client-row:focus-within > *,
                    .is-open .client-row > * { background: var(--row-hover); }

                    .client-row:hover > :first-child,
                    .client-row:focus-within > :first-child,
                    .is-open .client-row > :first-child { box-shadow: inset 3px 0 0 0 var(--accent); }

                    .is-last:not(.is-open) .client-row > * { border-block-end: 0; }

                    /* Single orchestrated load moment; the script takes over after the first interaction. */
                    .ledger:not(.is-live) .client-row {
                        animation: row-in var(--dur-base) var(--ease) backwards;
                        animation-delay: calc(min(var(--i), 14) * var(--stagger));
                    }

                    .toggle {
                        display: flex;
                        align-items: center;
                        gap: 12px;
                        inline-size: 100%;
                        padding: 12px 16px;
                        border: 0;
                        background: none;
                        color: inherit;
                        font: inherit;
                        text-align: start;
                        cursor: pointer;
                    }

                    .toggle:focus-visible { outline-offset: -2px; }

                    .chevron {
                        flex: none;
                        inline-size: .5rem;
                        block-size: .5rem;
                        border: solid var(--muted);
                        border-width: 0 1.8px 1.8px 0;
                        transform: rotate(-45deg);
                        transition: transform var(--dur-base) var(--ease), border-color var(--dur-fast);
                    }

                    .is-open .chevron { transform: rotate(45deg); border-color: var(--accent); }

                    .avatar {
                        flex: none;
                        display: inline-grid;
                        place-items: center;
                        inline-size: 34px;
                        block-size: 34px;
                        border-radius: 10px;
                        background: var(--accent-soft);
                        color: var(--accent);
                        font-size: .75rem;
                        font-weight: 650;
                        text-transform: uppercase;
                    }

                    .who { display: grid; line-height: 1.25; }
                    .who-name { font-weight: 600; }
                    .who-code { color: var(--muted); font-size: .8125rem; font-variant-numeric: tabular-nums; }

                    .sub-tags { display: grid; gap: 6px; justify-items: start; }
                    .sub-tag { display: inline-flex; align-items: center; gap: 8px; }
                    .sub-id { color: var(--muted); font-size: .8125rem; font-variant-numeric: tabular-nums; }
                    .muted { color: var(--muted); }
                    .due { color: var(--due); font-weight: 600; }

                    /* ---------- Chips and badges (never colour alone: icon, fill and text carry meaning) ---------- */
                    .chip {
                        display: inline-flex;
                        align-items: center;
                        gap: 6px;
                        padding: 2px 10px 2px 8px;
                        border-radius: 7px;
                        font-size: .8125rem;
                        font-weight: 600;
                    }

                    .chip::before {
                        content: "";
                        inline-size: 14px;
                        block-size: 14px;
                        background: currentColor;
                        -webkit-mask: var(--icon) center / contain no-repeat;
                        mask: var(--icon) center / contain no-repeat;
                    }

                    .chip-gsm { --icon: var(--icon-gsm); background: var(--accent-soft); color: var(--accent); }
                    .chip-fixe { --icon: var(--icon-fixe); background: var(--head); color: var(--ink); box-shadow: inset 0 0 0 1px var(--line); }

                    .badge {
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        padding: 3px 11px 3px 9px;
                        border-radius: 999px;
                        font-size: .8125rem;
                        font-weight: 600;
                        white-space: nowrap;
                    }

                    .badge::before { content: ""; inline-size: 8px; block-size: 8px; border-radius: 50%; background: currentColor; }
                    .badge-paid { background: var(--paid-soft); color: var(--paid); }
                    .badge-due { background: var(--due-soft); color: var(--due); }
                    .badge-due::before { background: transparent; box-shadow: inset 0 0 0 1.75px currentColor; }

                    /* ---------- Detail panel: height animates via grid-template-rows 0fr to 1fr ---------- */
                    .detail-row > td { padding: 0; background: var(--detail); }
                    .is-open .detail-row > td { border-block-end: 1px solid var(--line); }
                    .is-last .detail-row > td { border-block-end: 0; }

                    .reveal { display: grid; grid-template-rows: 0fr; transition: grid-template-rows var(--dur-slow) var(--ease); }
                    .reveal-inner { min-block-size: 0; overflow: hidden; visibility: hidden; transition: visibility 0s linear var(--dur-slow); }
                    .is-open .reveal { grid-template-rows: 1fr; }
                    .is-open .reveal-inner { visibility: visible; transition-delay: 0s; }

                    .detail { display: grid; gap: 22px; padding: 6px 20px 22px 68px; }

                    .sub-head { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; margin-block-end: 10px; }
                    .sub-title { font-weight: 600; }
                    .sub-meta { color: var(--muted); font-size: .875rem; }
                    .sub-total { margin-inline-start: auto; color: var(--muted); font-size: .875rem; font-variant-numeric: tabular-nums; }

                    .inv-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: var(--radius-control); background: var(--surface); }
                    .inv { inline-size: 100%; border-collapse: collapse; font-size: .875rem; }

                    .inv th {
                        padding: 8px 14px;
                        background: var(--head);
                        color: var(--muted);
                        font-size: .75rem;
                        font-weight: 600;
                        text-align: start;
                    }

                    .inv td { padding: 10px 14px; border-block-start: 1px solid var(--line); font-variant-numeric: tabular-nums; }
                    .inv .num { text-align: end; }
                    .inv-id { font-weight: 600; }

                    /* ---------- Footer and empty state ---------- */
                    .panel-foot { margin: 0; padding: 12px 16px; border-block-start: 1px solid var(--line); color: var(--muted); font-size: .8125rem; }
                    .empty { padding: 48px 16px; text-align: center; color: var(--muted); }
                    .empty p { margin: 0 0 12px; }

                    /* ---------- Motion ---------- */
                    @keyframes row-in { from { opacity: 0; transform: translateY(8px); } }
                    @keyframes bar-in { from { clip-path: inset(0 100% 0 0); } to { clip-path: inset(0 0 0 0); } }

                    @media (prefers-reduced-motion: reduce) {
                        *, *::before, *::after {
                            animation-duration: .001ms !important;
                            animation-delay: 0ms !important;
                            transition-duration: .001ms !important;
                            transition-delay: 0ms !important;
                        }
                    }

                    /* ---------- Small screens: each client becomes a labelled card ---------- */
                    @media (max-width: 44rem) {
                        .masthead { grid-template-columns: 1fr; }
                        .toolbar, .filters { flex-direction: column; align-items: stretch; }
                        .search { inline-size: 100%; }
                        .segments { display: flex; }
                        .segment { flex: 1; justify-content: center; }
                        .ghost { justify-content: center; }

                        .ledger thead {
                            position: absolute;
                            inline-size: 1px;
                            block-size: 1px;
                            overflow: hidden;
                            clip-path: inset(50%);
                        }

                        .ledger, .ledger > tbody { display: block; }

                        .ledger .client-row { display: grid; gap: 0; padding-block-end: 8px; }

                        .ledger .client-row > * {
                            display: flex;
                            justify-content: space-between;
                            align-items: center;
                            gap: 16px;
                            padding: 6px 16px;
                            border: 0;
                            background: transparent;
                            box-shadow: none !important;
                        }

                        .ledger .client-row > th { display: block; padding: 0; }
                        .ledger .client-row > td::before { content: attr(data-label); color: var(--muted); font-size: .8125rem; }
                        .ledger .client-row > td.num { text-align: end; }

                        .ledger .detail-row, .ledger .detail-row > td { display: block; }
                        .ledger > tbody { border-block-end: 1px solid var(--line); }
                        .ledger > tbody.is-last { border-block-end: 0; }
                        .ledger .detail-row > td, .is-open .detail-row > td { border: 0; }
                        .detail { padding: 4px 16px 20px; }
                        .sub-total { margin-inline-start: 0; inline-size: 100%; }
                    }

                    @media print {
                        body { background: #fff; }
                        .toolbar, .panel-foot { display: none; }
                        .table-wrap { max-block-size: none; overflow: visible; }
                        .ledger:not(.is-live) .client-row, .split-seg { animation: none; }
                        .reveal { grid-template-rows: 1fr !important; }
                        .reveal-inner { visibility: visible !important; }
                    }
                ]]></style>
            </head>
            <body>
                <main class="shell">
                    <header class="masthead">
                        <div>
                            <h1>Clients et facturation</h1>
                            <p class="lede">
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$nb-clients"/>
                                    <xsl:with-param name="one" select="'client'"/>
                                    <xsl:with-param name="many" select="'clients'"/>
                                </xsl:call-template><xsl:text>, </xsl:text>
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$nb-subs"/>
                                    <xsl:with-param name="one" select="'abonnement'"/>
                                    <xsl:with-param name="many" select="'abonnements'"/>
                                </xsl:call-template><xsl:text>, </xsl:text>
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$nb-invoices"/>
                                    <xsl:with-param name="one" select="'facture'"/>
                                    <xsl:with-param name="many" select="'factures'"/>
                                </xsl:call-template><xsl:text>.</xsl:text>
                            </p>
                        </div>

                        <section class="recovery" aria-labelledby="recovery-label">
                            <p class="recovery-label" id="recovery-label">Reste à encaisser</p>
                            <p class="recovery-amount">
                                <xsl:value-of select="format-number($unpaid, '#&#160;##0,00', 'fr')"/><span class="currency"><xsl:value-of select="$currency"/></span>
                            </p>
                            <p class="recovery-note">
                                Sur <xsl:call-template name="money"><xsl:with-param name="value" select="$billed"/></xsl:call-template> facturés,
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$nb-unpaid"/>
                                    <xsl:with-param name="one" select="'facture impayée'"/>
                                    <xsl:with-param name="many" select="'factures impayées'"/>
                                </xsl:call-template>
                                chez
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$nb-debtors"/>
                                    <xsl:with-param name="one" select="'client'"/>
                                    <xsl:with-param name="many" select="'clients'"/>
                                </xsl:call-template>.
                            </p>
                            <xsl:if test="$billed &gt; 0">
                                <div class="split" role="img" aria-label="Répartition de la facturation : {$paid-share} % réglé, {$unpaid-share} % impayé">
                                    <span class="split-seg split-paid" style="--share: {$paid-share}"/>
                                    <span class="split-seg split-unpaid" style="--share: {$unpaid-share}"/>
                                </div>
                                <ul class="legend">
                                    <li>
                                        <span class="legend-name">Réglé</span>
                                        <span class="legend-value"><xsl:call-template name="money"><xsl:with-param name="value" select="$paid"/></xsl:call-template></span>
                                        <span class="legend-sub">
                                            <xsl:call-template name="count-noun">
                                                <xsl:with-param name="n" select="$nb-paid"/>
                                                <xsl:with-param name="one" select="'facture'"/>
                                                <xsl:with-param name="many" select="'factures'"/>
                                            </xsl:call-template>
                                        </span>
                                    </li>
                                    <li class="legend-due">
                                        <span class="legend-name">Impayé</span>
                                        <span class="legend-value"><xsl:call-template name="money"><xsl:with-param name="value" select="$unpaid"/></xsl:call-template></span>
                                        <span class="legend-sub">
                                            <xsl:call-template name="count-noun">
                                                <xsl:with-param name="n" select="$nb-unpaid"/>
                                                <xsl:with-param name="one" select="'facture'"/>
                                                <xsl:with-param name="many" select="'factures'"/>
                                            </xsl:call-template>
                                        </span>
                                    </li>
                                </ul>
                            </xsl:if>
                        </section>
                    </header>

                    <xsl:choose>
                        <xsl:when test="$nb-clients &gt; 0">
                            <section class="panel" aria-label="Liste des clients">
                                <!-- Revealed by the script: without JavaScript these controls would do nothing. -->
                                <div class="toolbar" id="toolbar" hidden="hidden">
                                    <label class="sr-only" for="q">Rechercher un client, un abonnement ou une facture</label>
                                    <input class="search" id="q" type="search" autocomplete="off"
                                           placeholder="Rechercher un client, un abonnement, une facture"/>
                                    <div class="filters">
                                        <div class="segments" role="group" aria-label="Filtrer par situation de paiement">
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'status'"/>
                                                <xsl:with-param name="value" select="'all'"/>
                                                <xsl:with-param name="label" select="'Tous'"/>
                                                <xsl:with-param name="count" select="$nb-clients"/>
                                            </xsl:call-template>
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'status'"/>
                                                <xsl:with-param name="value" select="'paid'"/>
                                                <xsl:with-param name="label" select="'À jour'"/>
                                                <xsl:with-param name="count" select="$nb-clients - $nb-debtors"/>
                                            </xsl:call-template>
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'status'"/>
                                                <xsl:with-param name="value" select="'unpaid'"/>
                                                <xsl:with-param name="label" select="'Impayés'"/>
                                                <xsl:with-param name="count" select="$nb-debtors"/>
                                            </xsl:call-template>
                                        </div>
                                        <div class="segments" role="group" aria-label="Filtrer par type d’abonnement">
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'type'"/>
                                                <xsl:with-param name="value" select="'all'"/>
                                                <xsl:with-param name="label" select="'Toutes offres'"/>
                                                <xsl:with-param name="count" select="$nb-clients"/>
                                            </xsl:call-template>
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'type'"/>
                                                <xsl:with-param name="value" select="'GSM'"/>
                                                <xsl:with-param name="label" select="'GSM'"/>
                                                <xsl:with-param name="count" select="count($clients[abonnement[not(@type = 'FIXE')]])"/>
                                            </xsl:call-template>
                                            <xsl:call-template name="segment">
                                                <xsl:with-param name="group" select="'type'"/>
                                                <xsl:with-param name="value" select="'FIXE'"/>
                                                <xsl:with-param name="label" select="'Fixe'"/>
                                                <xsl:with-param name="count" select="count($clients[abonnement/@type = 'FIXE'])"/>
                                            </xsl:call-template>
                                        </div>
                                        <button class="ghost" id="expand-all" type="button">Tout déplier</button>
                                    </div>
                                </div>

                                <!-- Explicit ARIA roles keep table semantics when CSS turns rows into cards on mobile. -->
                                <div class="table-wrap" role="region" aria-label="Tableau des clients" tabindex="0">
                                    <table class="ledger" id="clients" role="table">
                                        <thead role="rowgroup">
                                            <tr role="row">
                                                <xsl:call-template name="sortable-th"><xsl:with-param name="label" select="'Client'"/></xsl:call-template>
                                                <th role="columnheader" scope="col"><span class="th-label">Abonnements</span></th>
                                                <xsl:call-template name="sortable-th">
                                                    <xsl:with-param name="label" select="'Facturé'"/>
                                                    <xsl:with-param name="type" select="'number'"/>
                                                    <xsl:with-param name="numeric" select="true()"/>
                                                </xsl:call-template>
                                                <xsl:call-template name="sortable-th">
                                                    <xsl:with-param name="label" select="'Impayé'"/>
                                                    <xsl:with-param name="type" select="'number'"/>
                                                    <xsl:with-param name="numeric" select="true()"/>
                                                </xsl:call-template>
                                                <xsl:call-template name="sortable-th">
                                                    <xsl:with-param name="label" select="'Statut'"/>
                                                    <xsl:with-param name="type" select="'number'"/>
                                                </xsl:call-template>
                                            </tr>
                                        </thead>
                                        <xsl:apply-templates select="$clients"/>
                                    </table>
                                </div>

                                <div class="empty" id="empty" hidden="hidden">
                                    <p>Aucun client ne correspond à ces critères.</p>
                                    <button class="ghost" id="reset" type="button">Réinitialiser les filtres</button>
                                </div>

                                <p class="panel-foot" id="count" aria-live="polite">
                                    <xsl:value-of select="$nb-clients"/> sur <xsl:value-of select="$nb-clients"/> client<xsl:if test="$nb-clients &gt; 1">s</xsl:if>
                                </p>
                            </section>
                        </xsl:when>
                        <xsl:otherwise>
                            <section class="panel empty"><p>Aucun client enregistré pour le moment.</p></section>
                        </xsl:otherwise>
                    </xsl:choose>
                </main>

                <script><![CDATA[
                    (function () {
                        'use strict';

                        var table = document.getElementById('clients');
                        if (!table) { return; }

                        var MAX_ANIMATED_ROWS = 12;
                        var STAGGER_MS = 18;
                        var DURATION_MS = 220;
                        var EASING = 'cubic-bezier(.2, .7, .2, 1)';

                        var original = Array.prototype.slice.call(table.tBodies);   // one tbody per client
                        var headers = Array.prototype.slice.call(table.querySelectorAll('thead th'));
                        var segments = Array.prototype.slice.call(document.querySelectorAll('.segment'));
                        var input = document.getElementById('q');
                        var counter = document.getElementById('count');
                        var emptyState = document.getElementById('empty');
                        var resetButton = document.getElementById('reset');
                        var expandAll = document.getElementById('expand-all');
                        var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

                        var state = { query: '', status: 'all', type: 'all', column: -1, direction: 1 };
                        var visible = original.slice();

                        // Accent- and case-insensitive matching: "bajoury" or "Éric" both work.
                        function fold(text) {
                            return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
                        }

                        function isOpen(group) { return group.classList.contains('is-open'); }

                        function setOpen(group, open) {
                            group.classList.toggle('is-open', open);
                            group.querySelector('.toggle').setAttribute('aria-expanded', String(open));
                        }

                        function sortValue(group, index) {
                            var cell = group.rows[0].cells[index];
                            return cell.dataset.sort !== undefined ? cell.dataset.sort : cell.textContent.trim();
                        }

                        function compare(a, b, type) {
                            if (type === 'number') { return parseFloat(a) - parseFloat(b); }
                            return a.localeCompare(b, 'fr', { sensitivity: 'base', numeric: true });
                        }

                        function matches(group) {
                            var statusOk = state.status === 'all' || group.dataset.status === state.status;
                            var typeOk = state.type === 'all' ||
                                (' ' + group.dataset.types + ' ').indexOf(' ' + state.type + ' ') !== -1;
                            var queryOk = !state.query || group.dataset.search.indexOf(state.query) !== -1;
                            return statusOk && typeOk && queryOk;
                        }

                        // A search hit that lives only in the detail (an invoice number, say) opens its client
                        // so the match is visible; it closes again when the match goes away.
                        function revealSearchHit(group) {
                            var detailOnly = !!state.query && group.dataset.rowSearch.indexOf(state.query) === -1;
                            if (detailOnly) {
                                setOpen(group, true);
                                group.dataset.auto = '1';
                            } else if (group.dataset.auto) {
                                setOpen(group, false);
                                delete group.dataset.auto;
                            }
                        }

                        function syncExpandAll() {
                            var allOpen = visible.length > 0 && visible.every(isOpen);
                            expandAll.textContent = allOpen ? 'Tout replier' : 'Tout déplier';
                            expandAll.disabled = visible.length === 0;
                        }

                        // Motion that answers a user action: a short staggered re-entry of the visible rows.
                        function replay(groups) {
                            if (reduceMotion.matches || !groups.length || !groups[0].rows[0].animate) { return; }
                            groups.slice(0, MAX_ANIMATED_ROWS).forEach(function (group, index) {
                                group.rows[0].animate(
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
                                    return state.direction * compare(sortValue(a, state.column), sortValue(b, state.column), type);
                                });
                            }

                            visible = [];
                            ordered.forEach(function (group) {
                                var show = matches(group);
                                group.hidden = !show;
                                group.classList.remove('is-last');
                                table.appendChild(group);
                                if (show) {
                                    visible.push(group);
                                    revealSearchHit(group);
                                }
                            });
                            if (visible.length) { visible[visible.length - 1].classList.add('is-last'); }

                            counter.textContent = visible.length + ' sur ' + original.length +
                                ' client' + (original.length > 1 ? 's' : '');
                            emptyState.hidden = visible.length > 0;
                            syncExpandAll();
                            if (animate) { replay(visible); }
                        }

                        function setFilter(name, value) {
                            state[name] = value;
                            segments.forEach(function (segment) {
                                if (segment.dataset.group === name) {
                                    segment.setAttribute('aria-pressed', String(segment.dataset.filter === value));
                                }
                            });
                        }

                        // Index once: the whole group (master + detail) for search, the master row alone for hit placement.
                        original.forEach(function (group) {
                            group.dataset.search = fold(group.textContent);
                            group.dataset.rowSearch = fold(group.rows[0].textContent);
                        });

                        // Master row click (or Enter/Space on its button) toggles the detail.
                        table.addEventListener('click', function (event) {
                            var row = event.target.closest('.client-row');
                            if (!row) { return; }
                            var group = row.parentNode;
                            delete group.dataset.auto;
                            setOpen(group, !isOpen(group));
                            syncExpandAll();
                        });

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
                                setFilter(segment.dataset.group, segment.dataset.filter);
                                render(true);
                            });
                        });

                        // No replay while typing: re-animating on every keystroke is noise.
                        input.addEventListener('input', function () {
                            state.query = fold(input.value.trim());
                            render(false);
                        });

                        expandAll.addEventListener('click', function () {
                            var open = !visible.every(isOpen);
                            visible.forEach(function (group) {
                                delete group.dataset.auto;
                                setOpen(group, open);
                            });
                            syncExpandAll();
                        });

                        resetButton.addEventListener('click', function () {
                            input.value = '';
                            state.query = '';
                            setFilter('status', 'all');
                            setFilter('type', 'all');
                            render(true);
                            input.focus();
                        });

                        syncExpandAll();
                        document.getElementById('toolbar').hidden = false;
                    }());
                ]]></script>
            </body>
        </html>
    </xsl:template>

    <!-- ========================================================= Master: one client = one tbody -->
    <xsl:template match="client">
        <xsl:variable name="billed-c" select="sum(abonnement/facture/@montant)"/>
        <xsl:variable name="unpaid-c" select="sum(abonnement/facture[@reglee = 'non']/@montant)"/>
        <xsl:variable name="unpaid-n" select="count(abonnement/facture[@reglee = 'non'])"/>

        <tbody role="rowgroup" style="--i: {position()}">
            <xsl:attribute name="class">
                <xsl:text>client</xsl:text>
                <xsl:if test="position() = last()"><xsl:text> is-last</xsl:text></xsl:if>
            </xsl:attribute>
            <xsl:attribute name="data-status">
                <xsl:choose>
                    <xsl:when test="$unpaid-n &gt; 0">unpaid</xsl:when>
                    <xsl:otherwise>paid</xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
            <!-- DTD default for @type is GSM, so anything that is not FIXE counts as GSM. -->
            <xsl:attribute name="data-types">
                <xsl:if test="abonnement[not(@type = 'FIXE')]">GSM </xsl:if>
                <xsl:if test="abonnement[@type = 'FIXE']">FIXE</xsl:if>
            </xsl:attribute>

            <tr class="client-row" role="row">
                <th scope="row" role="rowheader" data-label="Client" data-sort="{@nom}">
                    <button class="toggle" type="button" aria-expanded="false" aria-controls="detail-{@code}">
                        <span class="chevron" aria-hidden="true"></span>
                        <span class="avatar" aria-hidden="true">
                            <xsl:call-template name="initials"><xsl:with-param name="name" select="@nom"/></xsl:call-template>
                        </span>
                        <span class="who">
                            <span class="who-name"><xsl:value-of select="@nom"/></span>
                            <span class="who-code"><xsl:value-of select="@code"/></span>
                        </span>
                    </button>
                </th>
                <td role="cell" data-label="Abonnements">
                    <span class="sub-tags">
                        <xsl:for-each select="abonnement">
                            <span class="sub-tag">
                                <xsl:call-template name="type-chip"><xsl:with-param name="type" select="@type"/></xsl:call-template>
                                <span class="sub-id"><xsl:value-of select="@num"/></span>
                            </span>
                        </xsl:for-each>
                    </span>
                </td>
                <td role="cell" class="num" data-label="Facturé" data-sort="{format-number($billed-c, '0.00')}">
                    <xsl:call-template name="money"><xsl:with-param name="value" select="$billed-c"/></xsl:call-template>
                </td>
                <td role="cell" class="num" data-label="Impayé" data-sort="{format-number($unpaid-c, '0.00')}">
                    <xsl:choose>
                        <xsl:when test="$unpaid-c &gt; 0">
                            <span class="due"><xsl:call-template name="money"><xsl:with-param name="value" select="$unpaid-c"/></xsl:call-template></span>
                        </xsl:when>
                        <xsl:otherwise>
                            <span class="muted" aria-hidden="true">—</span><span class="sr-only">Aucun impayé</span>
                        </xsl:otherwise>
                    </xsl:choose>
                </td>
                <td role="cell" data-label="Statut" data-sort="{$unpaid-n}">
                    <xsl:choose>
                        <xsl:when test="$unpaid-n &gt; 0">
                            <span class="badge badge-due">
                                <xsl:call-template name="count-noun">
                                    <xsl:with-param name="n" select="$unpaid-n"/>
                                    <xsl:with-param name="one" select="'impayée'"/>
                                    <xsl:with-param name="many" select="'impayées'"/>
                                </xsl:call-template>
                            </span>
                        </xsl:when>
                        <xsl:otherwise><span class="badge badge-paid">À jour</span></xsl:otherwise>
                    </xsl:choose>
                </td>
            </tr>

            <tr class="detail-row" role="row">
                <td role="cell" colspan="5">
                    <div class="reveal" id="detail-{@code}">
                        <div class="reveal-inner">
                            <div class="detail">
                                <xsl:apply-templates select="abonnement" mode="detail"/>
                            </div>
                        </div>
                    </div>
                </td>
            </tr>
        </tbody>
    </xsl:template>

    <!-- ========================================================= Detail: subscription and its invoices -->
    <xsl:template match="abonnement" mode="detail">
        <section>
            <header class="sub-head">
                <xsl:call-template name="type-chip"><xsl:with-param name="type" select="@type"/></xsl:call-template>
                <span class="sub-title">Abonnement <xsl:value-of select="@num"/></span>
                <span class="sub-meta">
                    Souscrit le
                    <xsl:call-template name="date-fr"><xsl:with-param name="iso" select="@dateAb"/></xsl:call-template>
                </span>
                <span class="sub-total">
                    <xsl:call-template name="count-noun">
                        <xsl:with-param name="n" select="count(facture)"/>
                        <xsl:with-param name="one" select="'facture'"/>
                        <xsl:with-param name="many" select="'factures'"/>
                    </xsl:call-template>,
                    <xsl:call-template name="money"><xsl:with-param name="value" select="sum(facture/@montant)"/></xsl:call-template>
                </span>
            </header>
            <div class="inv-wrap">
                <table class="inv">
                    <caption class="sr-only">Factures de l’abonnement <xsl:value-of select="@num"/></caption>
                    <thead>
                        <tr>
                            <th scope="col">Facture</th>
                            <th scope="col">Date</th>
                            <th scope="col" class="num">Montant</th>
                            <th scope="col">Statut</th>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:apply-templates select="facture" mode="detail"/>
                    </tbody>
                </table>
            </div>
        </section>
    </xsl:template>

    <xsl:template match="facture" mode="detail">
        <!-- DTD default for @reglee is "oui": only an explicit "non" means unpaid. -->
        <xsl:variable name="is-unpaid" select="@reglee = 'non'"/>
        <tr>
            <td class="inv-id"><xsl:value-of select="@numFact"/></td>
            <td><xsl:call-template name="date-fr"><xsl:with-param name="iso" select="@dateFact"/></xsl:call-template></td>
            <td class="num">
                <xsl:if test="$is-unpaid"><xsl:attribute name="class">num due</xsl:attribute></xsl:if>
                <xsl:call-template name="money"><xsl:with-param name="value" select="@montant"/></xsl:call-template>
            </td>
            <td>
                <xsl:choose>
                    <xsl:when test="$is-unpaid"><span class="badge badge-due">Impayée</span></xsl:when>
                    <xsl:otherwise><span class="badge badge-paid">Réglée</span></xsl:otherwise>
                </xsl:choose>
            </td>
        </tr>
    </xsl:template>

    <!-- ========================================================= Reusable building blocks -->

    <xsl:template name="sortable-th">
        <xsl:param name="label"/>
        <xsl:param name="type" select="'text'"/>
        <xsl:param name="numeric" select="false()"/>
        <th role="columnheader" scope="col" aria-sort="none" data-type="{$type}">
            <xsl:if test="$numeric"><xsl:attribute name="class">num</xsl:attribute></xsl:if>
            <button class="sort" type="button"><xsl:value-of select="$label"/></button>
        </th>
    </xsl:template>

    <xsl:template name="segment">
        <xsl:param name="group"/>
        <xsl:param name="value"/>
        <xsl:param name="label"/>
        <xsl:param name="count"/>
        <button class="segment" type="button" data-group="{$group}" data-filter="{$value}" aria-pressed="{$value = 'all'}">
            <xsl:value-of select="$label"/>
            <span class="segment-count"><xsl:value-of select="$count"/></span>
        </button>
    </xsl:template>

    <!-- GSM / Fixe chip. The icon is drawn in CSS, so no SVG namespace handling is needed. -->
    <xsl:template name="type-chip">
        <xsl:param name="type"/>
        <xsl:choose>
            <xsl:when test="$type = 'FIXE'"><span class="chip chip-fixe">Fixe</span></xsl:when>
            <xsl:otherwise><span class="chip chip-gsm">GSM</span></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- 1 236,49 DH (numbers arrive as numbers or as attribute strings; both convert). -->
    <xsl:template name="money">
        <xsl:param name="value"/>
        <xsl:value-of select="format-number($value, '#&#160;##0,00', 'fr')"/>
        <xsl:text>&#160;</xsl:text>
        <xsl:value-of select="$currency"/>
    </xsl:template>

    <!-- ISO 2026-11-01 becomes "1 nov. 2026", wrapped in a machine-readable time element. -->
    <xsl:template name="date-fr">
        <xsl:param name="iso"/>
        <xsl:variable name="month" select="number(substring($iso, 6, 2))"/>
        <xsl:choose>
            <xsl:when test="string-length($iso) = 10 and $month &gt;= 1 and $month &lt;= 12">
                <time datetime="{$iso}">
                    <xsl:value-of select="number(substring($iso, 9, 2))"/>
                    <xsl:text>&#160;</xsl:text>
                    <xsl:value-of select="normalize-space(substring($months, ($month - 1) * 5 + 1, 5))"/>
                    <xsl:text>&#160;</xsl:text>
                    <xsl:value-of select="substring($iso, 1, 4)"/>
                </time>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="$iso"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- French plural rule: 0 and 1 are singular. -->
    <xsl:template name="count-noun">
        <xsl:param name="n"/>
        <xsl:param name="one"/>
        <xsl:param name="many"/>
        <xsl:value-of select="$n"/>
        <xsl:text>&#160;</xsl:text>
        <xsl:choose>
            <xsl:when test="$n &gt;= 2"><xsl:value-of select="$many"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="$one"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- First letters of the first two words ("EL Bajoury Youssef" gives "EB"); one-word names use two letters. -->
    <xsl:template name="initials">
        <xsl:param name="name"/>
        <xsl:variable name="clean" select="normalize-space($name)"/>
        <xsl:variable name="first" select="substring-before(concat($clean, ' '), ' ')"/>
        <xsl:variable name="rest" select="substring-after($clean, ' ')"/>
        <xsl:value-of select="substring($first, 1, 1)"/>
        <xsl:choose>
            <xsl:when test="$rest != ''"><xsl:value-of select="substring($rest, 1, 1)"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="substring($first, 2, 1)"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>