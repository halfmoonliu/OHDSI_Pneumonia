library(dplyr)

baseUrl <- "https://atlas-demo.ohdsi.org/WebAPI"

# Naming scheme:
# < 100 = Indication cohorts
# >= 100 & < 200 = Outcomes
# >= 200 "Utility" cohorts for aggregated covariates, etc.

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = baseUrl,
  cohortIds = c(
    1796307,
    1796527,
    1796528
  ),
  generateStats = TRUE
)

cohortDefinitionSet <- cohortDefinitionSet |>
  mutate(
    cohortName = case_when(
      cohortId == 1796307 ~ "Pneumonia",
      cohortId == 1796527 ~ "Pneumonia CVD",
      cohortId == 1796528 ~ "Ventilator Support",
      TRUE ~ cohortName
    ),
    cohortId = case_when(
      cohortId == 1796307 ~ 101,
      cohortId == 1796527 ~ 102,
      cohortId == 1796528 ~ 201,
      TRUE ~ cohortId
    )
  )

CohortGenerator::saveCohortDefinitionSet(
  cohortDefinitionSet = cohortDefinitionSet,
  settingsFileName = "inst/cohorts.csv",
  jsonFolder = "inst/cohorts",
  sqlFolder = "inst/sql/sql_server",
)


# No negative control outcomes.