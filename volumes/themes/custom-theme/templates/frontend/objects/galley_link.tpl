{**
 * plugins/themes/customTheme/templates/frontend/objects/galley_link.tpl
 *
 * Overrides the core galley link to add a "View Article" button next to the
 * existing PDF button. The view link points at the same galley "view" URL and
 * opens the PDF inline in a new tab with the browser's built-in viewer
 * (server streams Content-Disposition: inline — see CustomThemePlugin).
 * No custom viewer, no pdf.js, no `download` attribute.
 *
 * @uses $galley Galley
 * @uses $parent Issue|Article Object which these galleys are attached to
 * @uses $publication Publication Optionally the publication (version) to which this galley is attached
 * @uses $isSupplementary bool Is this a supplementary file?
 * @uses $hasAccess bool Can this user access galleys for this context?
 * @uses $restrictOnlyPdf bool Is access only restricted to PDF galleys?
 * @uses $purchaseArticleEnabled bool Can this article be purchased?
 * @uses $currentJournal Journal The current journal context
 * @uses $journalOverride Journal An optional argument to override the current
 *       journal with a specific context
 *}

{* Override the $currentJournal context if desired *}
{if $journalOverride}
	{assign var="currentJournal" value=$journalOverride}
{/if}

{* Determine galley type and URL op *}
{if $galley->isPdfGalley()}
	{assign var="type" value="pdf"}
{else}
	{assign var="type" value="file"}
{/if}

{* Get path for URL *}
{if $parent instanceOf APP\issue\Issue}
	{assign var="page" value="issue"}
	{assign var="parentId" value=$parent->getBestIssueId()}
	{assign var="path" value=$parentId|to_array:$galley->getBestGalleyId()}
{else}{* APP\submission\Submission *}
	{assign var="page" value="article"}
	{if $publication}
		{if $publication->getId() !== $parent->getData('currentPublicationId')}
			{* Get a versioned link if we have an older publication *}
			{assign var="path" value=$parent->getBestId()|to_array:"version":$publication->getId():$galley->getBestGalleyId()}
		{else}
			{assign var="parentId" value=$publication->getData('urlPath')|default:$article->getId()}
			{assign var="path" value=$parentId|to_array:$galley->getBestGalleyId()}
		{/if}
	{else}
		{assign var="path" value=$parent->getBestId()|to_array:$galley->getBestGalleyId()}
	{/if}
{/if}

{* Get user access flag *}
{if !$hasAccess}
	{if $restrictOnlyPdf && $type=="pdf"}
		{assign var=restricted value="1"}
	{elseif !$restrictOnlyPdf}
		{assign var=restricted value="1"}
	{/if}
{/if}

{* Don't be frightened. This is just a link *}
<a class="{if $isSupplementary}obj_galley_link_supplementary{else}obj_galley_link{/if} {$type|escape}{if $restricted} restricted{/if}" href="{url page=$page op="view" path=$path}"{if $id} id="{$id}"{/if}{if $labelledBy} aria-labelledby="{$labelledBy}"{/if}>
	{* Add some screen reader text to indicate if a galley is restricted *}
	{if $restricted}
		<span class="pkp_screen_reader">
			{if $purchaseArticleEnabled}
				{translate key="reader.subscriptionOrFeeAccess"}
			{else}
				{translate key="reader.subscriptionAccess"}
			{/if}
		</span>
	{/if}

	{$galley->getGalleyLabel()|escape}

	{if $restricted && $purchaseFee && $purchaseCurrency}
		<span class="purchase_cost">
			{translate key="reader.purchasePrice" price=$purchaseFee currency=$purchaseCurrency}
		</span>
	{/if}
</a>
{if $type == 'pdf' && !$restricted && !$isSupplementary}
	{* Plain inline view link: direct download URL (served inline by the
	   theme, no pdf.js wrapper), browser PDF viewer, new tab *}
	{if $publication}
		{assign var="viewTitle" value=$publication->getLocalizedTitle()|strip_tags}
	{else}
		{assign var="viewTitle" value=$galley->getGalleyLabel()}
	{/if}
	<a class="obj_galley_link pdf view" href="{url page=$page op="download" path=$path}" target="_blank" rel="noopener" aria-label="View article: {$viewTitle|escape}">View Article</a>
{/if}
