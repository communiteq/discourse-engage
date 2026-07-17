export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-engage-surveys", { path: "surveys" });
  },
};
