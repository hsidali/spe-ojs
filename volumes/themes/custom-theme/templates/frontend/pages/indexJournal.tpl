{**
 * plugins/themes/customTheme/templates/frontend/pages/indexJournal.tpl
 *
 * Overrides the core journal index to add a journal identity hero band
 * (title, description excerpt, ISSN/publisher meta, CTAs) above the
 * standard homepage blocks. All core blocks are preserved unchanged.
 *
 * @uses $currentContext Journal The current journal
 * @uses $journalDescription string Journal description
 * @uses $homepageImage object Homepage image
 * @uses $additionalHomeContent string Additional homepage content
 * @uses $announcements array Announcements
 * @uses $numAnnouncementsHomepage int Number of announcements on homepage
 * @uses $issue Issue Current issue
 *}
{include file="frontend/components/header.tpl" pageTitleTranslated=$currentJournal->getLocalizedName()}

<div class="page_index_journal">

	{call_hook name="Templates::Index::journal"}

	{* ── Journal identity hero ── *}
	{if $currentContext}
		{capture assign="heroDescription"}{$currentContext->getLocalizedData('description')|strip_tags}{/capture}
		{capture assign="heroOnlineIssn"}{$currentContext->getData('onlineIssn')}{/capture}
		{capture assign="heroPrintIssn"}{$currentContext->getData('printIssn')}{/capture}
		{capture assign="heroPublisher"}{$currentContext->getData('publisherInstitution')}{/capture}
		<section class="journal_hero" aria-label="{$currentJournal->getLocalizedName()|escape}">
			<div class="journal_hero_inner">
				<p class="journal_hero_eyebrow">{translate key="plugins.themes.customTheme.hero.eyebrow"}</p>
				<h1 class="journal_hero_title">{$currentJournal->getLocalizedName()|escape}</h1>
				{if $heroDescription}
					<p class="journal_hero_description">{$heroDescription|truncate:280:"…"|escape}</p>
				{/if}
				{if $heroOnlineIssn || $heroPrintIssn || $heroPublisher}
					<ul class="journal_hero_meta">
						{if $heroOnlineIssn}
							<li>e-ISSN {$heroOnlineIssn|escape}</li>
						{/if}
						{if $heroPrintIssn}
							<li>p-ISSN {$heroPrintIssn|escape}</li>
						{/if}
						{if $heroPublisher}
							<li>{translate key="plugins.themes.customTheme.footer.publishedBy"} {$heroPublisher|escape}</li>
						{/if}
					</ul>
				{/if}
				<div class="journal_hero_actions">
					{if $issue}
						<a class="journal_hero_btn journal_hero_btn_primary" href="{url page="issue" op="view" path=$issue->getBestIssueId()}">
							{translate key="plugins.themes.customTheme.hero.viewCurrentIssue"}
						</a>
					{/if}
					<a class="journal_hero_btn journal_hero_btn_outline" href="{url page="about" op="submissions"}">
						{translate key="plugins.themes.customTheme.makeSubmission"}
					</a>
				</div>
			</div>
		</section>
	{/if}

	{if $highlights->count()}
		{include file="frontend/components/highlights.tpl" highlights=$highlights}
	{/if}

	{if $activeTheme && !$activeTheme->getOption('useHomepageImageAsHeader') && $homepageImage}
		<div class="homepage_image">
			<img src="{$publicFilesDir}/{$homepageImage.uploadName|escape:"url"}"{if $homepageImage.altText} alt="{$homepageImage.altText|escape}"{/if}>
		</div>
	{/if}

	{* Journal Description *}
	{if $activeTheme && $activeTheme->getOption('showDescriptionInJournalIndex')}
		<section class="homepage_about">
			<a id="homepageAbout"></a>
			<h2>{translate key="about.aboutContext"}</h2>
			{$currentContext->getLocalizedData('description')}
		</section>
	{/if}

	{include file="frontend/objects/announcements_list.tpl" numAnnouncements=$numAnnouncementsHomepage}

	{* Latest issue *}
	{if $issue}
		<section class="current_issue">
			<a id="homepageIssue"></a>
			<h2>
				{translate key="journal.currentIssue"}
			</h2>
			<div class="current_issue_title">
				{$issue->getIssueIdentification()|escape}
			</div>
			{include file="frontend/objects/issue_toc.tpl" heading="h3"}
			<a href="{url router=PKP\core\PKPApplication::ROUTE_PAGE page="issue" op="archive"}" class="read_more">
				{translate key="journal.viewAllIssues"}
			</a>
		</section>
	{/if}

	{* Additional Homepage Content *}
	{if $additionalHomeContent}
		<div class="additional_content">
			{$additionalHomeContent}
		</div>
	{/if}
</div><!-- .page -->

{include file="frontend/components/footer.tpl"}
