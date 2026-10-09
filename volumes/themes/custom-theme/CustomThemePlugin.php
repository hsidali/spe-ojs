<?php

/**
 * @file plugins/themes/customTheme/CustomThemePlugin.php
 *
 * Copyright (c) 2014-2021 Simon Fraser University
 * Copyright (c) 2003-2021 John Willinsky
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class CustomThemePlugin
 *
 * @brief Custom theme
 */

namespace APP\plugins\themes\customTheme;

use APP\core\Application;
use APP\file\PublicFileManager;
use PKP\config\Config;
use PKP\core\PKPSessionGuard;

class CustomThemePlugin extends \PKP\plugins\ThemePlugin
{
    /**
     * @copydoc ThemePlugin::isActive()
     */
    public function isActive()
    {
        if (PKPSessionGuard::isSessionDisable()) {
            return true;
        }
        return parent::isActive();
    }

    /**
     * Initialize the theme's styles, scripts and hooks. This is run on the
     * currently active theme and it's parent themes.
     *
     */
    public function init()
    {
        // Register theme options

        // Typography is hardcoded to Poppins (loaded via Google Fonts in poppins.less)
        // No font option is needed — Poppins is set in variables.less

        $this->addOption('baseColour', 'FieldColor', [
            'label' => __('plugins.themes.default.option.colour.label'),
            'description' => __('plugins.themes.default.option.colour.description'),
            'default' => '#2563EB',
        ]);

        $this->addOption('showDescriptionInJournalIndex', 'FieldOptions', [
            'label' => __('manager.setup.contextSummary'),
            'options' => [
                [
                    'value' => true,
                    'label' => __('plugins.themes.default.option.showDescriptionInJournalIndex.option'),
                ],
            ],
            'default' => false,
        ]);
        $this->addOption('useHomepageImageAsHeader', 'FieldOptions', [
            'label' => __('plugins.themes.default.option.useHomepageImageAsHeader.label'),
            'description' => __('plugins.themes.default.option.useHomepageImageAsHeader.description'),
            'options' => [
                [
                    'value' => true,
                    'label' => __('plugins.themes.default.option.useHomepageImageAsHeader.option')
                ],
            ],
            'default' => false,
        ]);
        $this->addOption('displayStats', 'FieldOptions', [
            'type' => 'radio',
            'label' => __('plugins.themes.default.option.displayStats.label'),
            'options' => [
                [
                    'value' => 'none',
                    'label' => __('plugins.themes.default.option.displayStats.none'),
                ],
                [
                    'value' => 'bar',
                    'label' => __('plugins.themes.default.option.displayStats.bar'),
                ],
                [
                    'value' => 'line',
                    'label' => __('plugins.themes.default.option.displayStats.line'),
                ],
            ],
            'default' => 'none',
        ]);


        // Load primary stylesheet
        $this->addStyle('stylesheet', 'styles/index.less');

        // Store additional LESS variables to process based on options
        $additionalLessVariables = [];

        // Update colour based on theme option
        if (($baseColour = $this->getOption('baseColour')) !== '#2563EB') {
            if (!preg_match('/^#[0-9a-fA-F]{1,6}$/', $baseColour)) $baseColour = '#2563EB'; // pkp/pkp-lib#11974
            $additionalLessVariables[] = '@bg-base:' . $baseColour . ';';
            $additionalLessVariables[] = '@primary:' . $baseColour . ';';
            if (!$this->isColourDark($baseColour)) {
                $additionalLessVariables[] = '@text-bg-base:rgba(0,0,0,0.84);';
                $additionalLessVariables[] = '@bg-base-border-color:rgba(0,0,0,0.2);';
            }
        }

        // Pass additional LESS variables based on options
        if (!empty($additionalLessVariables)) {
            $this->modifyStyle('stylesheet', ['addLessVariables' => join("\n", $additionalLessVariables)]);
        }

        $request = Application::get()->getRequest();

        // Load icon font FontAwesome - http://fontawesome.io/
        $this->addStyle(
            'fontAwesome',
            $request->getBaseUrl() . '/lib/pkp/styles/fontawesome/fontawesome.css',
            ['baseUrl' => '']
        );

        // Get homepage image and use as header background if useAsHeader is true
        $context = Application::get()->getRequest()->getContext();
        if ($context && $this->getOption('useHomepageImageAsHeader') && ($homepageImage = $context->getLocalizedData('homepageImage'))) {
            $publicFileManager = new PublicFileManager();
            $publicFilesDir = $request->getBaseUrl() . '/' . $publicFileManager->getContextFilesPath($context->getId());
            $homepageImageUrl = $publicFilesDir . '/' . $homepageImage['uploadName'];

            $this->addStyle(
                'homepageImage',
                '.pkp_structure_head { background: center / cover no-repeat url("' . $homepageImageUrl . '");}',
                ['inline' => true]
            );
        }

        // Load jQuery from a CDN or, if CDNs are disabled, from a local copy.
        $min = Config::getVar('general', 'enable_minified') ? '.min' : '';
        $jquery = $request->getBaseUrl() . '/js/build/jquery/jquery' . $min . '.js';
        $jqueryUI = $request->getBaseUrl() . '/js/build/jquery-ui/jquery-ui' . $min . '.js';

        // Use an empty `baseUrl` argument to prevent the theme from looking for
        // the files within the theme directory
        $this->addScript('jQuery', $jquery, ['baseUrl' => '']);
        $this->addScript('jQueryUI', $jqueryUI, ['baseUrl' => '']);

        // Load Bootsrap's dropdown
        $this->addScript('popper', 'js/lib/popper/popper.js');
        $this->addScript('bsUtil', 'js/lib/bootstrap/util.js');
        $this->addScript('bsDropdown', 'js/lib/bootstrap/dropdown.js');

        // Load Swiper for carousel
        $this->addScript('swiper', 'js/lib/swiper/swiper-bundle' . $min . '.js');
        $this->addStyle('swiper', 'js/lib/swiper/swiper-bundle' . $min . '.css');
        $this->addScript('swiper-i18n', $this->getSwiperI18n(), ['inline' => true]);

        // Load custom JavaScript for this theme
        $this->addScript('default', 'js/main.js');

        // Add navigation menu areas for this theme
        $this->addMenuArea(['primary', 'user']);
    }

    /**
     * Get the name of the settings file to be installed on new journal
     * creation.
     *
     * @return string
     */
    public function getContextSpecificPluginSettingsFile()
    {
        return $this->getPluginPath() . '/settings.xml';
    }

    /** @see ThemePlugin::saveOption */
    public function saveOption($name, $value, $contextId = null) {
        // Validate the base colour setting value.
        if ($name == 'baseColour' && !preg_match('/^#[0-9a-fA-F]{1,6}$/', $value)) $value = null;

        parent::saveOption($name, $value, $contextId);
    }

    /**
     * Get the name of the settings file to be installed site-wide when
     * OJS is installed.
     *
     * @return string
     */
    public function getInstallSitePluginSettingsFile()
    {
        return $this->getPluginPath() . '/settings.xml';
    }

    /**
     * Get the display name of this plugin
     *
     * @return string
     */
    public function getDisplayName()
    {
        return 'custom-theme';
    }

    /**
     * Get the description of this plugin
     *
     * @return string
     */
    public function getDescription()
    {
        return 'Custom editable theme based on the OJS default theme.';
    }

    /**
     * Get the locale strings for the swiper carousel
     */
    public function getSwiperI18n(): string
    {
        return 'var pkpDefaultThemeI18N = ' . json_encode([
            'nextSlide' => __('plugins.themes.default.nextSlide'),
            'prevSlide' => __('plugins.themes.default.prevSlide'),
        ]);
    }
}

if (!PKP_STRICT_MODE) {
    class_alias('\APP\plugins\themes\customTheme\CustomThemePlugin', '\CustomThemePlugin');
}
