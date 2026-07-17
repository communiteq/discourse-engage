import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseEngageSurveysEntriesRoute extends DiscourseRoute {
  model(params) {
    return ajax(
      `/admin/plugins/discourse-engage/api/surveys/${params.survey_id}/entries`
    ).then((result) => ({
      survey: result.survey,
      entries: result.entries || [],
    }));
  }
}
