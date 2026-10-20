{**
 * plugins/themes/customTheme/templates/frontend/components/navigationMenu.tpl
 *
 * Overrides the core navigation menu to add inline Lucide SVG icons to the
 * Register (user-plus) and Login (log-in) links in the user menu.
 * 18px, stroke 1.75, currentColor. No icon fonts, no emoji.
 *
 * @uses navigationMenu array Hierarchical array of navigation menu item assignments
 * @uses id string Element ID to assign the outer <ul>
 * @uses ulClass string Class name(s) to assign the outer <ul>
 * @uses liClass string Class name(s) to assign all <li> elements
 *}

{if $navigationMenu}
	<ul id="{$id|escape}" class="{$ulClass|escape} pkp_nav_list">
		{foreach key=field item=navigationMenuItemAssignment from=$navigationMenu->menuTree}
			{if !$navigationMenuItemAssignment->navigationMenuItem->getIsDisplayed()}
				{continue}
			{/if}
			{capture assign="menuItemTitle"}{$navigationMenuItemAssignment->navigationMenuItem->getLocalizedTitle()}{/capture}
			{if !$menuItemTitle|trim}
				{continue}
			{/if}
			{capture assign="menuItemUrl"}{$navigationMenuItemAssignment->navigationMenuItem->getUrl()}{/capture}
			<li class="{$liClass|escape}">
				<a href="{$menuItemUrl|escape}">
					{if $id == 'navigationUser' && $menuItemUrl|strstr:'user/register'}
						<svg class="pkp_nav_icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 21a8 8 0 0 1 13.292-6"/><circle cx="10" cy="8" r="5"/><path d="M19 16v6"/><path d="M22 19h-6"/></svg>
					{elseif $id == 'navigationUser' && $menuItemUrl|strstr:'/login'}
						<svg class="pkp_nav_icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" x2="3" y1="12" y2="12"/></svg>
					{/if}
					{$navigationMenuItemAssignment->navigationMenuItem->getLocalizedTitle()}
				</a>
				{if $navigationMenuItemAssignment->navigationMenuItem->getIsChildVisible()}
					<ul>
						{foreach key=childField item=childNavigationMenuItemAssignment from=$navigationMenuItemAssignment->children}
							{if $childNavigationMenuItemAssignment->navigationMenuItem->getIsDisplayed()}
								{capture assign="childTitle"}{$childNavigationMenuItemAssignment->navigationMenuItem->getLocalizedTitle()}{/capture}
								{if $childTitle|trim}
								<li class="{$liClass|escape}">
									<a href="{$childNavigationMenuItemAssignment->navigationMenuItem->getUrl()}">
										{$childNavigationMenuItemAssignment->navigationMenuItem->getLocalizedTitle()}
									</a>
								</li>
								{/if}
							{/if}
						{/foreach}
					</ul>
				{/if}
			</li>
		{/foreach}
	</ul>
{/if}
