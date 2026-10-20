{**
 * plugins/themes/customTheme/templates/frontend/components/footer.tpl
 *
 * Overrides the core footer with a navy 3-column academic footer:
 * About / Quick Links / Contact, plus a bottom bar with copyright
 * and the OJS brand. Preserves $pageFooter and $brandImage.
 *
 * @uses $currentContext Journal The current journal (when in journal context)
 * @uses $pageFooter string Footer content from site/journal settings
 * @uses $brandImage string OJS brand image path
 * @uses $baseUrl string Base URL
 *}
	</div><!-- pkp_structure_main -->

	{* Sidebars *}
	{if empty($isFullWidth)}
		{capture assign="sidebarCode"}{call_hook name="Templates::Common::Sidebar"}{/capture}
		{if $sidebarCode}
			<div class="pkp_structure_sidebar left" role="complementary">
				{$sidebarCode}
			</div><!-- pkp_sidebar.left -->
		{/if}
	{/if}
</div><!-- pkp_structure_content -->

<div class="pkp_structure_footer_wrapper" role="contentinfo">
	<a id="pkp_content_footer"></a>

	<div class="pkp_structure_footer">
		<div class="pkp_footer_columns">
			<div class="pkp_footer_col pkp_footer_about">
				{if $currentContext}
					<p class="pkp_footer_heading">{$currentContext->getLocalizedName()|escape}</p>
					{capture assign="footerDescription"}{$currentContext->getLocalizedData('description')|strip_tags}{/capture}
					{if $footerDescription}
						<p class="pkp_footer_text">{$footerDescription|truncate:200:"…"|escape}</p>
					{/if}
					{capture assign="footerPublisher"}{$currentContext->getData('publisherInstitution')}{/capture}
					{if $footerPublisher}
						<p class="pkp_footer_text pkp_footer_publisher">{translate key="plugins.themes.customTheme.footer.publishedBy"} {$footerPublisher|escape}</p>
					{/if}
				{/if}
				{if $pageFooter}
					<div class="pkp_footer_content">
						{$pageFooter}
					</div>
				{/if}
			</div>
			<nav class="pkp_footer_col pkp_footer_links" aria-label="{translate key="plugins.themes.customTheme.footer.quickLinks"}">
				<p class="pkp_footer_heading">{translate key="plugins.themes.customTheme.footer.quickLinks"}</p>
				<ul>
					<li><a href="{url page="issue" op="current"}">{translate key="journal.currentIssue"}</a></li>
					<li><a href="{url page="issue" op="archive"}">{translate key="journal.viewAllIssues"}</a></li>
					<li><a href="{url page="about"}">{translate key="about.aboutContext"}</a></li>
					<li><a href="{url page="about" op="submissions"}">{translate key="plugins.themes.customTheme.makeSubmission"}</a></li>
					<li><a href="{url page="about" op="contact"}">{translate key="about.contact"}</a></li>
				</ul>
			</nav>
			<div class="pkp_footer_col pkp_footer_contact">
				<p class="pkp_footer_heading">{translate key="plugins.themes.customTheme.footer.contact"}</p>
				{if $currentContext}
					{capture assign="contactEmail"}{$currentContext->getData('contactEmail')}{/capture}
					{capture assign="contactName"}{$currentContext->getData('contactName')}{/capture}
					{capture assign="onlineIssn"}{$currentContext->getData('onlineIssn')}{/capture}
					<ul>
						{if $contactName}
							<li>{$contactName|escape}</li>
						{/if}
						{if $contactEmail}
							<li><a href="mailto:{$contactEmail|escape}">{$contactEmail|escape}</a></li>
						{/if}
						{if $onlineIssn}
							<li>e-ISSN {$onlineIssn|escape}</li>
						{/if}
					</ul>
				{/if}
			</div>
		</div>

		<div class="pkp_brand_footer">
			<span class="pkp_footer_copyright">
				&copy; {$smarty.now|date_format:"Y"} {$currentContext->getLocalizedName()|escape|default:$siteTitle|escape}
			</span>
			<a href="{url page="about" op="aboutThisPublishingSystem"}">
				<img alt="{translate key="about.aboutThisPublishingSystem"}" src="{$baseUrl}/{$brandImage}">
			</a>
		</div>
	</div>
</div><!-- pkp_structure_footer_wrapper -->

</div><!-- pkp_structure_page -->

{load_script context="frontend"}

{call_hook name="Templates::Common::Footer::PageFooter"}
</body>
</html>
