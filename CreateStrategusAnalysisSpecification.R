# =============================================================================
# Creating a Strategus Analysis Specification: Pneumonia Exacerbation
# =============================================================================
#
# Study question:
#   Does the comorbidity of cardiovascular diseases have an impact of pneumonia patient's risk of mechanical ventilation?
#
#   This study aims at investigating whether the cardiovascular comorbidities have an impact on pneumonia patient exacerbation,
#   defined as the need for mechanical ventilation. 
#   
# This script follows the three-step pattern from the "Creating Analysis
# Specification" walkthrough:
#   Step 1: Load cohorts and shared assets
#   Step 2: Instantiate modules and create module specifications
#   Step 3: Compose the full analysis specification and save as JSON
#
# Modules used (Part 1 scope -- no CohortMethod, SCCS, or PLP):
#   - CohortGeneratorModule
#   - CohortDiagnosticsModule
#   - CohortIncidenceModule
#   - CharacterizationModule
#
# Module reference docs:
#   https://ohdsi.github.io/Strategus/reference/CohortGeneratorModule.html
#   https://ohdsi.github.io/Strategus/reference/CohortDiagnosticsModule.html
#   https://ohdsi.github.io/Strategus/reference/CohortIncidenceModule.html
#   https://ohdsi.github.io/Strategus/reference/CharacterizationModule.html
#
# TIP: For any module, you can inspect ALL parameters and their defaults with:
#
#   formals(someModule$createModuleSpecifications)
#
# =============================================================================
remotes::install_github("OHDSI/CohortIncidence@v4.1.0", force = TRUE)
remotes::install_github("OHDSI/Characterization@v2.2.0", force = TRUE)
remotes::install_github("OHDSI/CohortMethod@v5.5.2", force = TRUE)
remotes::install_github("OHDSI/CohortGenerator@v1.0.2", force = TRUE)
library(Strategus)

dir.create("inst", recursive = TRUE, showWarnings = FALSE)


# =============================================================================
# STEP 1: Study Inputs -- Cohorts and Shared Resources
# =============================================================================
#
# Every Strategus study starts with cohort definitions. These become
# "sharedResources" in the analysis specification because any module
# (diagnostics, incidence, characterization, etc.) can reference them.
#
# The following cohorts were built on ATLAS:
#   1796307 --  Pneumonia
#   1796527 --  Pneumonia + CVD  
#   1796528 --  Ventilator Support  
# -----------------------------------------------------------------------------

baseUrl <- "https://atlas-demo.ohdsi.org/WebAPI"
ROhdsiWebApi::getWebApiVersion(baseUrl = baseUrl)

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl       = baseUrl,
  cohortIds     = c(
    1796307, # Pneumonia  
    1796527, # Pneumonia + CVD    
    1796528  # Ventilator Support    
  ),
  generateStats = TRUE
)

cohortDefinitionSet[, c("cohortId", "cohortName")]

# NOTE: Negative control outcomes are optional for this course workflow.
# The PDF includes them for CohortMethod/SCCS -- we skip them here.


# =============================================================================
# STEP 2: Assemble HADES Modules
# =============================================================================
#
# The pattern for every module is:
#   1. Instantiate the module object        (e.g., CohortGeneratorModule$new())
#   2. Create module specifications          (e.g., module$createModuleSpecifications(...))
#   3. Later, add to the analysis spec       (Step 3)
# -----------------------------------------------------------------------------


# --- 2.1 CohortGenerator Module ----------------------------------------------
# Ref: https://ohdsi.github.io/Strategus/reference/CohortGeneratorModule.html
#
# Generates cohorts in the CDM. The cohort definitions themselves go into
# sharedResources (not the module spec) so other modules can use them too.
#
# createModuleSpecifications defaults:
#   generateStats = TRUE   -- compute cohort inclusion/generation statistics

cgModule <- CohortGeneratorModule$new()

cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(
	cohortDefinitionSet = cohortDefinitionSet
)

cohortGeneratorModuleSpecifications <- cgModule$createModuleSpecifications(
	generateStats = TRUE                    # TRUE: include steps to compute inclusion rule statistics.
)


# --- 2.2 CohortDiagnostics Module --------------------------------------------
# Ref: https://ohdsi.github.io/Strategus/reference/CohortDiagnosticsModule.html
# See also: https://ohdsi.github.io/CohortDiagnostics/
#
# Runs a battery of diagnostic checks on each cohort.
#
# -----------------------------------------------------------------------------

cdModule <- CohortDiagnosticsModule$new()

cohortDiagnosticsModuleSpecifications <- cdModule$createModuleSpecifications(
	cohortIds = NULL,                           # NULL: (all cohorts)
	runInclusionStatistics = TRUE,              # TRUE: Generate and export statistic on the cohort inclusion rules
	runIncludedSourceConcepts = TRUE,           # TRUE: Generate and export the source concepts included in the cohorts
	runOrphanConcepts = TRUE,                   # TRUE: Look for missing concepts that should be correlated to what you are looking for
	runTimeSeries = TRUE,                       # TRUE: Look at patients counts and visit counts over time
	runVisitContext = TRUE,                     # TRUE: Generate and export index-date visit context
	runBreakdownIndexEvents = TRUE,             # TRUE: Run concept-level breakdown of index events
	runIncidenceRate = TRUE,                    # TRUE: Generate and export the cohort incidence rate over time.
	runCohortRelationship = TRUE,               # TRUE: Run temporal overlap between cohorts
	runTemporalCohortCharacterization = TRUE,   # TRUE: Incidence rate by year/ month
	minCharacterizationMean = 0.01,             # 0.01: Reduce the file size of the characterization output
	irWashoutPeriod = 7                         # 7: At least have 7 days before index date without diagnosis
	# temporalCovariateSettings = <module default covariate settings>
)


# --- 2.3 CohortIncidence Module -----------------------------------------------
# Ref: https://ohdsi.github.io/Strategus/reference/CohortIncidenceModule.html
# See also: https://ohdsi.github.io/CohortIncidence/
#
# Computes incidence rates for target cohorts x outcome x time-at-risk windows.
#
# createModuleSpecifications defaults:
#   irDesign = NULL  -- you MUST supply this; no meaningful default
#
# The design choices live in the sub-objects (targets, outcomes, TARs, strata).
# Sub-object docs:
#   https://ohdsi.github.io/CohortIncidence/reference/createOutcomeDef.html
#   https://ohdsi.github.io/CohortIncidence/reference/createTimeAtRiskDef.html
#   https://ohdsi.github.io/CohortIncidence/reference/createStrataSettings.html
#   https://ohdsi.github.io/CohortIncidence/reference/createCohortRef.html
#   https://ohdsi.github.io/CohortIncidence/reference/createIncidenceDesign.html
#-------------------------------------------------------------------------------


ciModule <- CohortIncidenceModule$new()

targets <- list(
	CohortIncidence::createCohortRef(id = 101, name = "Pneumonia"),
	CohortIncidence::createCohortRef(id = 102, name = "PneumoniaCVD")
)

outcomes <- list(
	CohortIncidence::createOutcomeDef(
		id = 201, #outcome
		name = "Mechanical Ventilation",
		cohortId = 1796528,   # Ventilator Support
		cleanWindow = 7      # : ventilation within 7 days would be counted only once
	)
)

tars <- list(
	CohortIncidence::createTimeAtRiskDef(
		id = 101,
		startWith = "start",   # "start": anchor-start
		endWith = "end"        # "end": anchor-end
	),
	CohortIncidence::createTimeAtRiskDef(
		id = 102,
		startWith = "start",   # "start": anchor-start
		endWith = "end"  ,     # override: anchor end to start
		endOffset = 0          # 0: do not extend
	)
)

incidenceAnalysis <- CohortIncidence::createIncidenceAnalysis(
	targets = c(101, 102),
	outcomes = c(201),
	tars = c(101, 102)
)

irDesign <- CohortIncidence::createIncidenceDesign(
	targetDefs = targets,
	outcomeDefs = outcomes,
	tars = tars,
	analysisList = list(incidenceAnalysis),
	strataSettings = CohortIncidence::createStrataSettings(
		byYear = TRUE,         # TRUE: see trends in years
		byGender = TRUE        # TRUE: see trends by gender
	)
)

cohortIncidenceModuleSpecifications <- ciModule$createModuleSpecifications(
	irDesign = irDesign$toList()
)


# --- 2.4 Characterization Module ----------------------------------------------
# Ref: https://ohdsi.github.io/Strategus/reference/CharacterizationModule.html
# See also: https://ohdsi.github.io/Characterization/
#
# Produces baseline feature summaries for target cohorts with respect to the
# outcome.

#-------------------------------------------------------------------------------


cModule <- CharacterizationModule$new()

characterizationModuleSpecifications <- cModule$createModuleSpecifications(
	targetIds = c(101, 102),
	outcomeIds = 201,
	outcomeWashoutDays = c(7),                  # 7: Count ventilation again after 7 days
	minPriorObservation = 365,                  # 365 days of minimum observation a patient in the target populations must have
	dechallengeStopInterval = 14,               # 14 days: Count as another pneumonia event after 14 days
	dechallengeEvaluationWindow = 0,            # 0 days: Because pneumonia/or need for ventilation is short-term
	riskWindowStart = c(0, 0),                  # default: c(0, 0) 0 day after entering the cohort that we start to look for ventilation records
	startAnchor = c("cohort start",             # default: c("cohort start",
	                "cohort start"),            #            "cohort start")
	riskWindowEnd = c(0, 0),                    # default: c(0, 0): How many days after the cohort anchor end date
	endAnchor = c("cohort end",                 # default: c("cohort end",
	              "cohort end"),                #            "cohort end")
	minCharacterizationMean = 0.01,             # 0.01: Min fraction patients in the target have a covariate to be included
	casePreTargetDuration = 365,                # 365: Number of days before target start to use for case-series
	casePostOutcomeDuration = 365,              # 365: The number of days after outcome start to use for case-series
	includeTimeToEvent = TRUE,                  # TRUE: Count number of days between risk window start and outcome event
	includeDechallengeRechallenge = TRUE,       # TRUE: Include dechallenge/ rechallenge
	includeAggregateCovariate = TRUE            # TRUE: Run the aggregate covariate 
	# covariateSettings     = <broad default: demographics, conditions, drugs,
	#                          procedures, measurements at -365d and -30d windows>
	# caseCovariateSettings = <during-exposure covariates: conditions, drugs,
	#                          procedures, devices, measurements, observations>
)


# --- 2.5 CohortMethod Module ---------------------------------------------------
# Ref: https://ohdsi.github.io/Strategus/reference/CohortMethodModule.html
# See also: https://ohdsi.github.io/CohortMethod/
#
# Estimates comparative treatment effect between celecoxib and diclofenac
# for the GI bleed outcome using a propensity-score stratified cohort design.

# -------------------------------------------------------------------------------

cmModule <- CohortMethodModule$new()

targetComparatorOutcomesList <- list(
  CohortMethod::createTargetComparatorOutcomes(
    targetId = 101, # pneumonia
    comparatorId = 102, # pneumonia + CVD
    outcomes = list(
      CohortMethod::createOutcome(
        outcomeId = 201, # ventilator support
        outcomeOfInterest = TRUE    # default: TRUE
      )
    )
  )
)

cmAnalysisList <- list(
  CohortMethod::createCmAnalysis(
      analysisId = 1,                           # default: 1
      description = "pneumonia vs pneumonia plus cardiovascular disease for ventilator support", 
      getDbCohortMethodDataArgs = CohortMethod::createGetDbCohortMethodDataArgs(
      
      removeDuplicateSubjects = "keep all",     # "keep all": count all encounters
      firstExposureOnly = FALSE,                # FALSE: not only first exposure
      washoutPeriod = 7,                        # 7: At least have 7 days before index date without diagnosis
      studyStartDate = "",                      # "": do not specify
      studyEndDate = "",                        # "": do not specify
      restrictToCommonPeriod = FALSE,           # FALSE: only one treatment
      maxCohortSize = 0,                        # 0: no maximum size
      covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
    ),
    createStudyPopArgs = CohortMethod::createCreateStudyPopulationArgs(
      removeSubjectsWithPriorOutcome = FALSE,  # include subject with prior outcome
      priorOutcomeLookback = 99999,          # 99999: no upper limit
      minDaysAtRisk = 1,                     # 1: minimum 1 day at risk
      maxDaysAtRisk = 99999,                 # 99999: no upper limit
      riskWindowStart = 0,                   # 0: starts from day 0
      startAnchor = "cohort start",          # default: "cohort start"  
      riskWindowEnd = 0,                     # 0: ends with anchor
      endAnchor = "cohort end",              # default: "cohort end"
      censorAtNewRiskWindow = FALSE          # FALSE: no overlap possible
    ),
    createPsArgs = CohortMethod::createCreatePsArgs(
      maxCohortSizeForFitting = 250000,        # 250000: not likely to exceed
      errorOnHighCorrelation = TRUE,           # TRUE: throw an error when covariates have high correlation
      stopOnError = TRUE                       # TRUE: stop on error
    ),
    stratifyByPsArgs = CohortMethod::createStratifyByPsArgs(
      numberOfStrata = 5,                      #  5: use strata for propensity score matching
      stratificationColumns = c(),             #  c()
      baseSelection = "all"                    # "all"
    ),
    fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
      modelType = "logistic",                  # "logistic": use logistic regression
      stratified = TRUE,                       # TRUE: Stratified propensity score matching
      useCovariates = FALSE,                   # FALSE: Do not use covariates
      inversePtWeighting = FALSE,              # FALSE
    )
  )
)

cohortMethodModuleSpecifications <- cmModule$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList
  # analysesToExclude = NULL,                 # default: NULL
  # refitPsForEveryOutcome = FALSE,           # FALSE: a single propensity model will be fitted
  # refitPsForEveryStudyPopulation = TRUE,    # TRUE: the propensity model be fitted for every study population definition
  # cmDiagnosticThresholds = CohortMethod::createCmDiagnosticThresholds()
)

# =============================================================================
# STEP 3: Compose and Save the Analysis Specification JSON
# =============================================================================
#
# Composition order:
#   1. Start with an empty specification
#   2. Add shared resources (cohort definitions)
#   3. Add each module specification
#   4. Save to JSON with ParallelLogger
#
# The resulting JSON is the primary design artifact -- it can be:
#   - Version-controlled and diffed
#   - Reviewed without database access
#   - Executed later at any OMOP CDM site
# -----------------------------------------------------------------------------

analysisSpecifications <- createEmptyAnalysisSpecifications() |>
	addSharedResources(cohortDefinitionSharedResource) |>
	addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
	addModuleSpecifications(cohortDiagnosticsModuleSpecifications) |>
	addModuleSpecifications(cohortIncidenceModuleSpecifications) |>
	addModuleSpecifications(characterizationModuleSpecifications) |>
  addModuleSpecifications(cohortMethodModuleSpecifications)


ParallelLogger::saveSettingsToJson(
	object = analysisSpecifications,
	fileName = "inst/settings/PneumoniaSpecsYLiu_20260313.json"
)

message("Analysis specification saved to: inst/settings/PneumoniaSpecsYLiu.json")
