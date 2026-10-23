// Single source of truth for private workspace routes and section tabs.
// This is presentation/navigation policy only. Database permissions remain authoritative.
export const ROLE_LABELS = {
  admin: "Admin",
  chairman: "Chairman",
  vice_chairman: "Vice Chairman",
  secretary: "Secretary",
  treasurer: "Treasurer",
  team_manager: "Team Manager",
  coach: "Coach",
  assistant_coach: "Assistant Coach",
  media_team: "Media Team",
  sponsor_lead: "Sponsor Lead",
  sponsor: "Sponsor",
  kit_manager: "Kit Manager",
  player_welfare: "Player Welfare",
  player: "Player",
  supporter: "Supporter"
};

export const PAGE_ACCESS = {
  "workspace.html": ["admin","chairman","secretary","team_manager","player_welfare"],
  "coach.html": ["admin","chairman","coach"],
  "secretary.html": ["admin","chairman","secretary"],
  "treasurer.html": ["admin","chairman","treasurer"],
  "media.html": ["admin","chairman","media_team"],
  "sponsor-lead.html": ["admin","chairman","sponsor_lead"],
  "sponsor.html": ["admin","sponsor"],
  "sponsor-links.html": ["admin","chairman","sponsor_lead"],
  "kit.html": ["admin","chairman","secretary","team_manager","coach","assistant_coach","kit_manager"],
  "home-attendance.html": ["admin","chairman","vice_chairman","secretary","treasurer","team_manager","coach","media_team","sponsor_lead"],
  "social-stats.html": ["admin","chairman","secretary","treasurer","team_manager","coach","media_team","sponsor_lead","sponsor"],
  "monthly-sponsor-report.html": ["admin","chairman","treasurer","secretary","media_team","sponsor"],
  "index.html": ["admin","chairman","vice_chairman","secretary","treasurer","team_manager","coach","assistant_coach","media_team","sponsor_lead","sponsor","kit_manager","player_welfare","player","supporter"]
};

export const PAGE_LABELS = {
  "workspace.html": "Club workspace",
  "coach.html": "Coach workspace",
  "secretary.html": "Secretary workspace",
  "treasurer.html": "Treasurer workspace",
  "media.html": "Media Team",
  "sponsor-lead.html": "Sponsor Lead",
  "sponsor.html": "Sponsor portal",
  "sponsor-links.html": "Sponsor account links",
  "kit.html": "Kit & equipment",
  "home-attendance.html": "Home attendance",
  "social-stats.html": "Social stats",
  "monthly-sponsor-report.html": "Monthly sponsor report"
};

// Each section is independently filtered, so multi-role users see the union without duplicates.
export const SECTION_LABELS = {
  "workspace.html": {
    player: "Players", fixture: "Fixtures & results", news: "News", sponsor: "Sponsors", activity: "Activities",
    tm_squad_admin: "Squad admin", tm_match_day: "Match day", tm_transport_logistics: "Transport & logistics",
    tm_team_sheet_report: "Team sheet & report", tm_discipline_welfare: "Discipline & welfare",
    tm_communication: "Communication", tm_training_coordination: "Training coordination",
    tm_reporting: "Reporting", tm_expenses: "Expenses & club finances"
  },
  "coach.html": {
    fixtures: "Fixtures & results", activities: "Activities", squad: "Squad list", training_plans: "Training plans",
    training_attendance: "Training attendance", match_selection: "Match selection", tactics_match_prep: "Tactics & prep",
    player_performance: "Player performance", match_analysis: "Match analysis", player_development: "Player development",
    fitness: "Injuries & fitness", discipline: "Discipline summary"
  },
  "treasurer.html": {
    transport: "Transport & logistics", expenses: "Expenses & club finances", opening: "Opening balance",
    income: "Income records", expense_records: "Expense records", transport_approvals: "Transport approvals",
    budget: "Budget", requisitions: "Requisitions", sponsor_fund: "Sponsor funds",
    member_contribution: "Player/member contributions", cashbook: "Cash book & receipts",
    financial_report: "Financial reports", audit: "Audit log"
  },
  "secretary.html": {
    player: "Players", fixture: "Fixtures & results", news: "News", sponsor: "Sponsors", activity: "Activities",
    meeting: "Meetings & minutes", correspondence: "Correspondence", registration: "Registration & licensing",
    membership: "Membership register", document: "Documents", notice: "Notices", election: "Elections & appointments", report: "Reports"
  },
  "media.html": {
    posts: "Social posts", calendar: "Calendar", stats: "Social stats", gallery: "Fans Gallery", hero: "Homepage hero"
  },
  "sponsor-lead.html": {
    sponsors: "Sponsors", pipeline: "Prospects & pipeline", evaluation: "Prospect evaluation", templates: "Proposal templates",
    proposals: "Proposals", packages: "Sponsorship packages", agreements: "Agreements", contributions: "Contributions",
    benefits: "Benefits delivery", communications: "Communication log", requests: "Requests to other roles", reports: "Sponsor reports"
  },
  "sponsor.html": {
    partnership: "My partnership", agreement: "My agreement", contributions: "My contributions", benefits: "Benefits delivered",
    updates: "Updates", media: "Sponsor media", requests: "Requests", report: "My report", details: "My details"
  }
};

export const SECTION_ACCESS = {
  "workspace.html": {
    player: ["admin","chairman","secretary","team_manager"],
    fixture: ["admin","chairman","secretary","team_manager"],
    news: ["admin","chairman","secretary","media_team"],
    sponsor: ["admin","chairman","secretary","sponsor_lead"],
    activity: ["admin","chairman","secretary","team_manager"],
    tm_squad_admin: ["admin","chairman","team_manager"],
    tm_match_day: ["admin","chairman","team_manager"],
    tm_transport_logistics: ["admin","chairman","team_manager","treasurer"],
    tm_team_sheet_report: ["admin","chairman","team_manager"],
    tm_discipline_welfare: ["admin","chairman","team_manager","player_welfare"],
    tm_communication: ["admin","chairman","team_manager"],
    tm_training_coordination: ["admin","chairman","team_manager"],
    tm_reporting: ["admin","chairman","team_manager"],
    tm_expenses: ["admin","chairman","treasurer"]
  },
  "coach.html": {
    fixtures: ["admin","chairman","coach"],
    activities: ["admin","chairman","coach"],
    squad: ["admin","chairman","coach"],
    fitness: ["admin","chairman","coach"],
    discipline: ["admin","chairman","coach"],
    training_plans: ["admin","chairman","coach"],
    training_attendance: ["admin","chairman","coach"],
    match_selection: ["admin","chairman","coach"],
    tactics_match_prep: ["admin","chairman","coach"],
    player_performance: ["admin","chairman","coach"],
    match_analysis: ["admin","chairman","coach"],
    player_development: ["admin","chairman","coach"]
  },
  "treasurer.html": {
    transport: ["admin","chairman","treasurer"],
    expenses: ["admin","chairman","treasurer"],
    opening: ["admin","chairman","treasurer"],
    income: ["admin","chairman","treasurer"],
    expense_records: ["admin","chairman","treasurer"],
    transport_approvals: ["admin","chairman","treasurer"],
    budget: ["admin","chairman","treasurer"],
    requisitions: ["admin","chairman","treasurer"],
    sponsor_fund: ["admin","chairman","treasurer"],
    member_contribution: ["admin","chairman","treasurer"],
    cashbook: ["admin","chairman","treasurer"],
    financial_report: ["admin","chairman","treasurer"],
    audit: ["admin","chairman","treasurer"]
  },
  "secretary.html": {
    meeting: ["admin","chairman","secretary"], correspondence: ["admin","chairman","secretary"], registration: ["admin","chairman","secretary"], membership: ["admin","chairman","secretary"], document: ["admin","chairman","secretary"], notice: ["admin","chairman","secretary"], election: ["admin","chairman","secretary"], report: ["admin","chairman","secretary"],
    player: ["admin","chairman","secretary"], fixture: ["admin","chairman","secretary"], news: ["admin","chairman","secretary"], sponsor: ["admin","chairman","secretary"], activity: ["admin","chairman","secretary"]
  },
  "media.html": {
    posts: ["admin","chairman","media_team"],
    calendar: ["admin","chairman","media_team"],
    stats: ["admin","chairman","media_team"],
    gallery: ["admin","chairman","media_team"],
    hero: ["admin","chairman","media_team"]
  },
  "sponsor-lead.html": {
    sponsors: ["admin","chairman","sponsor_lead"],
    pipeline: ["admin","chairman","sponsor_lead"],
    evaluation: ["admin","chairman","sponsor_lead"],
    templates: ["admin","chairman","sponsor_lead"],
    proposals: ["admin","chairman","sponsor_lead"],
    packages: ["admin","chairman","sponsor_lead"],
    agreements: ["admin","chairman","sponsor_lead"],
    contributions: ["admin","chairman","sponsor_lead"],
    benefits: ["admin","chairman","sponsor_lead"],
    communications: ["admin","chairman","sponsor_lead"],
    requests: ["admin","chairman","sponsor_lead"],
    reports: ["admin","chairman","sponsor_lead"]
  },
  "sponsor.html": {
    partnership: ["admin","sponsor"],
    agreement: ["admin","sponsor"],
    contributions: ["admin","sponsor"],
    benefits: ["admin","sponsor"],
    updates: ["admin","sponsor"],
    media: ["admin","sponsor"],
    requests: ["admin","sponsor"],
    report: ["admin","sponsor"],
    details: ["admin","sponsor"]
  }
};

export const PAGE_HOME = [
  { roles: ["admin","chairman"], page: "workspace.html" },
  { roles: ["sponsor"], page: "sponsor.html" },
  { roles: ["sponsor_lead"], page: "sponsor-lead.html" },
  { roles: ["media_team"], page: "media.html" },
  { roles: ["coach"], page: "coach.html" },
  { roles: ["treasurer"], page: "treasurer.html" },
  { roles: ["secretary"], page: "secretary.html" },
  { roles: ["kit_manager","assistant_coach"], page: "kit.html" },
  { roles: ["admin","chairman","team_manager","player_welfare"], page: "workspace.html" },
  { roles: ["vice_chairman"], page: "home-attendance.html" },
  { roles: ["player","supporter"], page: "index.html" }
];
