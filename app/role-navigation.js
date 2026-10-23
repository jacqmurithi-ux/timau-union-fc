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
  { roles: ["sponsor"], page: "sponsor.html" },
  { roles: ["sponsor_lead"], page: "sponsor-lead.html" },
  { roles: ["media_team"], page: "media.html" },
  { roles: ["coach"], page: "coach.html" },
  { roles: ["treasurer"], page: "treasurer.html" },
  { roles: ["secretary"], page: "secretary.html" },
  { roles: ["kit_manager","assistant_coach"], page: "kit.html" },
  { roles: ["admin","chairman","team_manager","player_welfare"], page: "workspace.html" },
  { roles: ["vice_chairman","player","supporter"], page: "index.html" }
];
