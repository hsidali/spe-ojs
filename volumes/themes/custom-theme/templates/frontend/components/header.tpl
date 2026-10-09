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
