{**
 * plugins/themes/customTheme/templates/frontend/components/header.tpl
 *
 * Copyright (c) 2014-2021 Simon Fraser University
 * Copyright (c) 2003-2021 John Willinsky
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @brief Custom theme header with logo placeholder.
 *
 * LOGO PLACEMENT INSTRUCTIONS:
 * ============================
 * To add your real logo, go to:
 *   OJS Dashboard → Settings → Website → Appearance → Logo
 * Upload your logo image there (recommended: 200×60px, PNG or SVG with
 * transparent background). OJS will populate $displayPageHeaderLogo and
 * the logo will render automatically in the .pkp_site_name area below.
 *
 * The logo image is stored in the journal's public files directory and
 * referenced via $publicFilesDir/$displayPageHeaderLogo.uploadName.
 *
 * If no logo is uploaded, a visible placeholder box is shown instead.
 *
 * @uses $isFullWidth bool Should this page be displayed without sidebars?
 * @uses $displayPageHeaderLogo array|null Logo image data from journal settings
 * @uses $displayPageHeaderTitle string Journal name text fallback
 *}
{strip}
	{* Determine whether a logo or title string is being displayed *}
	{assign var="showingLogo" value=true}
	{if !$displayPageHeaderLogo}
		{assign var="showingLogo" value=false}
	{/if}
{/strip}
<!DOCTYPE html>
<html lang="{$currentLocale|replace:"_":"-"}" xml:lang="{$currentLocale|replace:"_":"-"}">
{if !$pageTitleTranslated}{capture assign="pageTitleTranslated"}{translate key=$pageTitle}{/capture}{/if}
{include file="frontend/components/headerHead.tpl"}
<body class="pkp_page_{$requestedPage|escape|default:"index"} pkp_op_{$requestedOp|escape|default:"index"}{if $showingLogo} has_site_logo{/if}" dir="{$currentLocaleLangDir|escape|default:"ltr"}">

	<div class="pkp_structure_page">

		{* Header *}
		<header class="pkp_structure_head" id="headerNavigationContainer" role="banner">
			{* Skip to content nav links *}
			{include file="frontend/components/skipLinks.tpl"}

			{* Utility top bar: ISSN / publisher / open access *}
			{if $currentContext}
				{capture assign="onlineIssn"}{$currentContext->getData('onlineIssn')}{/capture}
				{capture assign="printIssn"}{$currentContext->getData('printIssn')}{/capture}
				{capture assign="publisher"}{$currentContext->getData('publisherInstitution')}{/capture}
				{if $onlineIssn || $printIssn || $publisher}
					<div class="pkp_utility_bar">
						<div class="pkp_utility_bar_inner">
							<span class="pkp_utility_oa">
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
								{translate key="plugins.themes.customTheme.hero.eyebrow"}
							</span>
							{if $onlineIssn}
								<span class="pkp_utility_item">e-ISSN {$onlineIssn|escape}</span>
							{/if}
							{if $printIssn}
								<span class="pkp_utility_item">p-ISSN {$printIssn|escape}</span>
							{/if}
							{if $publisher}
								<span class="pkp_utility_item pkp_utility_publisher">{$publisher|escape}</span>
							{/if}
						</div>
					</div>
				{/if}
			{/if}

			<div class="pkp_head_wrapper">

				<div class="pkp_site_name_wrapper">
					<button class="pkp_site_nav_toggle">
						<span>Open Menu</span>
					</button>
					{if !$requestedPage || $requestedPage === 'index'}
						<h1 class="pkp_screen_reader">
							{if $currentContext}
								{$displayPageHeaderTitle|escape}
							{else}
								{$siteTitle|escape}
							{/if}
						</h1>
					{/if}
					<div class="pkp_site_name">
					{capture assign="homeUrl"}
						{url page="index" router=PKP\core\PKPApplication::ROUTE_PAGE}
					{/capture}
					{if $displayPageHeaderLogo}
						{**
						 * ✅ LOGO IS SET — uploaded via OJS Dashboard → Settings → Website → Appearance → Logo
						 * The image renders here automatically. Recommended size: 200×60px, PNG/SVG.
						 * File location on disk: {$publicFilesDir}/{$displayPageHeaderLogo.uploadName}
						 *}
						<a href="{$homeUrl}" class="is_img">
							<img src="{$publicFilesDir}/{$displayPageHeaderLogo.uploadName|escape:"url"}" width="{$displayPageHeaderLogo.width|escape}" height="{$displayPageHeaderLogo.height|escape}" {if $displayPageHeaderLogo.altText != ''}alt="{$displayPageHeaderLogo.altText|escape}"{/if} />
						</a>
					{elseif $displayPageHeaderTitle}
						{**
						 * ⬜ NO LOGO UPLOADED — showing journal name as text + a visible placeholder box.
						 * Upload a logo at: OJS Dashboard → Settings → Website → Appearance → Logo
						 * Recommended: 200×60px, PNG or SVG with transparent background.
						 *}
						<a href="{$homeUrl}" class="is_text">{$displayPageHeaderTitle|escape}</a>
						<a href="{$homeUrl}" class="logo_placeholder" title="Upload your logo in Settings → Website → Appearance → Logo">
							LOGO HERE<br/>(200&times;60px)
						</a>
					{else}
						{**
						 * ⬜ FALLBACK — no journal title or logo configured.
						 * Upload a logo at: OJS Dashboard → Settings → Website → Appearance → Logo
						 *}
						<a href="{$homeUrl}" class="logo_placeholder" title="Upload your logo in Settings → Website → Appearance → Logo">
							LOGO PLACEHOLDER<br/>(200&times;60px recommended)
						</a>
					{/if}
					</div>
				</div>

				{capture assign="primaryMenu"}
					{load_menu name="primary" id="navigationPrimary" ulClass="pkp_navigation_primary"}
				{/capture}

				<nav class="pkp_site_nav_menu" aria-label="{translate|escape key="common.navigation.site"}">
					<a id="siteNav"></a>
					<div class="pkp_navigation_primary_row">
						<div class="pkp_navigation_primary_wrapper">
							{* Primary navigation menu for current application *}
							{$primaryMenu}

							{* Search form *}
							{if $currentContext && $requestedPage !== 'search'}
								<div class="pkp_navigation_search_wrapper">
									<a href="{url page="search"}" class="pkp_search pkp_search_desktop">
										<span class="fa fa-search" aria-hidden="true"></span>
										{translate key="common.search"}
									</a>
								</div>
							{/if}
						</div>
					</div>
					<div class="pkp_navigation_user_wrapper" id="navigationUserWrapper">
						{load_menu name="user" id="navigationUser" ulClass="pkp_navigation_user" liClass="profile"}
					</div>
					{* Primary submission call to action — duplicated here so it
					   appears in the mobile menu (sidebar is desktop-only) *}
					{if $currentContext}
						<div class="pkp_navigation_submission_wrapper">
							<a href="{url page="about" op="submissions"}" class="pkp_navigation_submission">
								<svg class="pkp_nav_icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/></svg>
								{translate key="plugins.themes.customTheme.makeSubmission"}
							</a>
						</div>
					{/if}
				</nav>
			</div>{* .pkp_head_wrapper *}
		</header>{* .pkp_structure_head *}

		{* Wrapper for page content and sidebars *}
		{if $isFullWidth}
			{assign var=hasSidebar value=0}
		{/if}
		<div class="pkp_structure_content{if $hasSidebar} has_sidebar{/if}">
			<div class="pkp_structure_main" role="main">
				<a id="pkp_content_main"></a>
