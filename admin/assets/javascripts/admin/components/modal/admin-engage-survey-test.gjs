import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

let surveyJsLoader;
const SAFE_CORE_URL = "https://unpkg.com/survey-core/survey.core.min.js";
const SAFE_UI_URL = "https://unpkg.com/survey-js-ui/survey-js-ui.min.js";
const SAFE_CSS_URL = "https://unpkg.com/survey-core/survey-core.min.css";

function hasRenderer() {
  return (
    !!window.Survey?.SurveyNG?.render ||
    !!window.SurveyUI?.renderSurvey ||
    !!window.jQuery?.fn?.Survey
  );
}

function loadScript(url) {
  if ([...document.scripts].some((script) => script.src === url)) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = url;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Failed to load survey runtime script"));
    document.head.appendChild(script);
  });
}

function loadStylesheet(url) {
  if ([...document.styleSheets].some((sheet) => sheet.href === url)) {
    return;
  }

  if ([...document.querySelectorAll("link[rel='stylesheet']")].some((link) => link.href === url)) {
    return;
  }

  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = url;
  if (url !== SAFE_CSS_URL) {
    link.onerror = () => loadStylesheet(SAFE_CSS_URL);
  }
  document.head.appendChild(link);
}

function loadSurveyJs(scriptUrl, cssUrl) {
  if (window.Survey?.Model && hasRenderer()) {
    return Promise.resolve();
  }

  if (surveyJsLoader) {
    return surveyJsLoader;
  }

  surveyJsLoader = (async () => {
    const requestedScriptUrl = scriptUrl || SAFE_UI_URL;
    const requestedCssUrl = cssUrl || SAFE_CSS_URL;

    loadStylesheet(requestedCssUrl);

    if (/survey-jquery/i.test(requestedScriptUrl)) {
      await loadScript(SAFE_CORE_URL);
      await loadScript(SAFE_UI_URL);
      return;
    }

    await loadScript(requestedScriptUrl);

    if (!window.Survey?.Model) {
      await loadScript(SAFE_CORE_URL);
    }
    if (!hasRenderer()) {
      await loadScript(SAFE_UI_URL);
    }
  })();

  return surveyJsLoader;
}

export default class AdminEngageSurveyTest extends Component {
  @service siteSettings;

  @tracked loading = false;
  @tracked loadFailed = false;
  @tracked lastResult = null;

  get hasConfig() {
    const config = this.args.model?.survey_json;
    return !!config && Object.keys(config).length > 0;
  }

  get hasQuestionElements() {
    const pages = this.args.model?.survey_json?.pages;
    if (!Array.isArray(pages)) {
      return false;
    }

    return pages.some((page) => Array.isArray(page?.elements) && page.elements.length > 0);
  }

  @action
  async setupSurvey(element) {
    const config = this.args.model?.survey_json;

    if (!config || Object.keys(config).length === 0) {
      return;
    }

    this.loading = true;
    this.loadFailed = false;

    try {
      await loadSurveyJs(
        this.siteSettings.discourse_engage_surveyjs_url,
        this.siteSettings.discourse_engage_surveycss_url
      );

      const SurveyCtor = window.Survey?.Model;
      if (!SurveyCtor) {
        throw new Error("SurveyJS model not found");
      }

      const surveyModel = new SurveyCtor(config);
      surveyModel.onComplete.add((sender) => {
        this.lastResult = JSON.stringify(sender.data || {}, null, 2);
      });

      if (window.Survey?.SurveyNG?.render) {
        window.Survey.SurveyNG.render(element, { model: surveyModel });
      } else if (window.SurveyUI?.renderSurvey) {
        window.SurveyUI.renderSurvey(surveyModel, element);
      } else if (window.jQuery?.fn?.Survey) {
        window.jQuery(element).Survey({ model: surveyModel });
      } else {
        throw new Error("No browser renderer available");
      }
    } catch {
      this.loadFailed = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_engage.admin.test_modal.title"}}
      @closeModal={{@closeModal}}
      class="engage-survey-modal"
    >
      <:body>
        {{#if this.hasConfig}}
          {{#if this.loading}}
            <p>{{i18n "discourse_engage.admin.test_modal.loading"}}</p>
          {{/if}}

          {{#if this.loadFailed}}
            <p>{{i18n "discourse_engage.admin.test_modal.load_failed"}}</p>
          {{else}}
            {{#unless this.hasQuestionElements}}
              <p>{{i18n "discourse_engage.admin.test_modal.no_questions"}}</p>
            {{/unless}}
          {{/if}}

          <div class="engage-survey-host" {{didInsert this.setupSurvey}}></div>
        {{else}}
          <p>{{i18n "discourse_engage.admin.test_modal.no_config"}}</p>
        {{/if}}

        {{#if this.lastResult}}
          <div class="control-group">
            <label>{{i18n "discourse_engage.admin.test_modal.result"}}</label>
            <textarea class="form-control" readonly>{{this.lastResult}}</textarea>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
