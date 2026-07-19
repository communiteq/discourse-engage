import { withPluginApi } from "discourse/lib/plugin-api";
import EngageParticipationPrompt from "discourse/plugins/discourse-engage/discourse/components/modal/engage-participation-prompt";
import EngageSurveyModal from "discourse/plugins/discourse-engage/discourse/components/modal/engage-survey-modal";

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
  if (surveyJsLoader) {
    return surveyJsLoader;
  }

  surveyJsLoader =
    window.Survey?.Model && hasRenderer()
      ? Promise.resolve()
      : (async () => {
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

export default {
  name: "discourse-engage",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.discourse_engage_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("discourse-engage", [
        {
          label: "discourse_engage.admin.nav.surveys",
          route: "adminPlugins.show.discourse-engage-surveys",
        },
      ]);
    });

    const startedAt = Date.now();
    let lastFetchAt = 0;
    let eligibilityFetchInFlight = false;

    const initialDelayMs =
      Math.max(0, Number(siteSettings.discourse_engage_initial_delay_seconds || 60)) * 1000;
    const minFetchIntervalMs =
      Math.max(0, Number(siteSettings.discourse_engage_min_fetch_interval_seconds || 60)) * 1000;

    withPluginApi((api) => {
      api.onPageChange(async () => {
        const now = Date.now();
        if (now - startedAt < initialDelayMs) {
          return;
        }

        if (lastFetchAt && now - lastFetchAt < minFetchIntervalMs) {
          return;
        }

        if (eligibilityFetchInFlight) {
          return;
        }

        lastFetchAt = now;
        eligibilityFetchInFlight = true;

        try {
          const result = await fetch("/discourse-engage/eligible", {
            credentials: "same-origin",
            headers: { "X-Requested-With": "XMLHttpRequest" },
          });

          if (!result.ok) {
            return;
          }

          const json = await result.json();
          const survey = json.survey;
          if (!survey) {
            return;
          }

          await loadSurveyJs(
            siteSettings.discourse_engage_surveyjs_url,
            siteSettings.discourse_engage_surveycss_url
          );

          const modal = api.container.lookup("service:modal");
          
          // If both allow_decline and allow_defer are false, skip the participation prompt
          // and go straight to the survey
          if (survey.skip_prompt) {
            modal.show(EngageSurveyModal, {
              model: survey,
            });
          } else {
            modal.show(EngageParticipationPrompt, {
              model: survey,
            });
          }
        } catch {
          // Ignore prompt errors to avoid affecting app navigation.
        } finally {
          eligibilityFetchInFlight = false;
        }
      });
    });
  },
};
