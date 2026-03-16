## The effect of cardiovascular comorbidity on pneumonia exacerbation

<img src="https://img.shields.io/badge/Study%20Status-Repo%20Created-lightgray.svg" alt="Study Status: Repo Created">

- Analytics use case(s): **Strategus**
- Study type: **Clinical Application**
- Study lead: **Yun-Chung Liu**
- Study start date: **April 1 2026**
- Study end date: **TBD**
- Protocol: **In preparation**
- Publications: None
- Results explorer: None

## Description
This study aims to **investigate whether the presence of cardiovascular disease increases the probability of pneumonia exacerbation**. The **outcome of interest is the need for mechanical ventilation in hospital**. Because pneumonia is a short term condition that can occur multiple times on the same patient, we consider two admission with interval larger than 14 days two separate events. Propensity score matching will be applied for more appropriate comparison between pneumonia patient with and without the comorbidity of cardiovascular diseases. **The detail design specification can be found in the _CreateStrategusAnalysisSpecification.R_ file**. Below are some highlights.

### Diagnostics

```
cohortDiagnosticsModuleSpecifications <- cdModule$createModuleSpecifications(
	cohortIds = NULL,                           # NULL: (all cohorts)
	runInclusionStatistics = TRUE,              # TRUE: Generate and export statistic on the cohort inclusion rules
	runIncludedSourceConcepts = TRUE,           # TRUE: Generate and export the source concepts included in the cohorts
	runOrphanConcepts = TRUE,                   # TRUE: Look for missing concepts that should be correlated 
	runTimeSeries = TRUE,                       # TRUE: Look at patients counts and visit counts over time
	runVisitContext = TRUE,                     # TRUE: Generate and export index-date visit context
	runBreakdownIndexEvents = TRUE,             # TRUE: Run concept-level breakdown of index events
	runIncidenceRate = TRUE,                    # TRUE: Generate and export the cohort incidence rate over time.
	runCohortRelationship = TRUE,               # TRUE: Run temporal overlap between cohorts
	runTemporalCohortCharacterization = TRUE,   # TRUE: Incidence rate by year/ month
	minCharacterizationMean = 0.01,             # 0.01: Reduce the file size of the characterization output
	irWashoutPeriod = 7                         # 7: At least have 7 days before index date without diagnosis
  
)
```
### Incidence

Two cohort will be included for comparison in this study: pneumonia patients and pneumonia patients with cardiovascular diseases. The outcome of interest is mechanical ventilation (ventilation within 7 days will be counted only once).

### Chracterization

```
characterizationModuleSpecifications <- cModule$createModuleSpecifications(
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
)
```
### Population Estimation

```
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

```
