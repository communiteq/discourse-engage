import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseEngageSurveysEditRoute extends DiscourseRoute {
  model(params) {
    if (params.survey_id === "new") {
      return {
        id: null,
        title: "",
        priority: 0,
        status: "draft",
        allow_decline: true,
        allow_defer: true,
        rules_json: "{}",
        survey_json: "{}",
      };
    }

    return ajax(
      `/admin/plugins/discourse-engage/api/surveys/${params.survey_id}`
    ).then((result) => result.survey);
  }
}
