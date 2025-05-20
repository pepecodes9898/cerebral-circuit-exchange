;; Cerebral Circuit Exchange

;; =============================================================================
;; COGNITIVE MERIT ASSESSMENT FRAMEWORK
;; =============================================================================

;; Stores all merit assessments between synapse providers and receivers
(define-map synapse-merit-records {cortex-contributor: principal, assessor: principal} uint)
;; Tracks total number of assessments per contributor
(define-map merit-assessment-counts principal uint)
;; Stores cumulative merit points per contributor
(define-map cumulative-merit-points principal uint)

;; =============================================================================
;; SYNAPSE EXCHANGE REQUEST ARCHITECTURE
;; =============================================================================

;; Neural exchange request ledger
(define-map neural-exchange-requests
  {request-sequence: uint}
  {
    requester: principal,
    contributor: principal,
    time-units: uint,
    neuron-value: uint,
    phase: uint, ;; 0=pending, 1=accepted, 2=rejected, 3=completed
    neural-timestamp: uint
  }
)
(define-data-var request-sequence-tracker uint u1)

;; =============================================================================
;; CEREBRAL MANAGEMENT CONFIGURATION
;; =============================================================================

;; Protocol overseer identity
(define-constant cerebral-overseer tx-sender)

;; Neural protocol error definitions
(define-constant error-unauthorized-synapse (err u200))
(define-constant error-invalid-parameter-structure (err u212))
(define-constant error-threshold-violation (err u213))
(define-constant error-network-saturation (err u214))

;; Protocol tuning parameters
(define-data-var synaptic-base-unit-value uint u10)
(define-data-var contributor-capacity-threshold uint u100)
(define-data-var neural-network-fee-rate uint u10)
(define-data-var collective-capacity-limit uint u1000)

;; =============================================================================
;; PARTICIPANT NEURON STATE MONITORING
;; =============================================================================

;; Participant operation neural error codes
(define-constant error-insufficient-neurons (err u201))
(define-constant error-invalid-time-allocation (err u202))
(define-constant error-invalid-neuron-valuation (err u203))
(define-constant error-network-overload (err u204))
(define-constant error-dendrite-connection-refused (err u205))
(define-constant error-magnitude-outside-parameters (err u215))
(define-constant error-null-transmission-rejected (err u210))
(define-constant error-allocation-limit-exceeded (err u211))

;; Network capacity and participant state variables
(define-data-var neural-network-utilization uint u0)
(define-map cognitive-resource-inventory principal uint)
(define-map synaptic-token-reserves principal uint)
(define-map neural-resource-offerings {entity: principal} {time-allocation: uint, neural-price: uint})

;; =============================================================================
;; NEURAL UTILITY OPERATIONS
;; =============================================================================

;; Calculate network transmission fee for neural exchanges
(define-private (calculate-network-fee (neuron-count uint))
  (/ (* neuron-count (var-get neural-network-fee-rate)) u100))

;; Regulate network capacity allocations
(define-private (modify-network-capacity (capacity-delta int))
  (let (
    (current-network-usage (var-get neural-network-utilization))
    (adjusted-utilization (if (< capacity-delta 0)
                         (if (>= current-network-usage (to-uint (- 0 capacity-delta)))
                             (- current-network-usage (to-uint (- 0 capacity-delta)))
                             u0)
                         (+ current-network-usage (to-uint capacity-delta))))
  )
    (asserts! (<= adjusted-utilization (var-get collective-capacity-limit)) error-network-overload)
    (var-set neural-network-utilization adjusted-utilization)
    (ok true)))

;; =============================================================================
;; COGNITIVE EXCHANGE INTERFACE
;; =============================================================================

;; Register neural resource availability in the marketplace
(define-public (broadcast-cognitive-availability (time-units uint) (neuron-price uint))
  (let (
    (available-resources (default-to u0 (map-get? cognitive-resource-inventory tx-sender)))
    (current-offerings (get time-allocation (default-to {time-allocation: u0, neural-price: u0} 
                                         (map-get? neural-resource-offerings {entity: tx-sender}))))
    (updated-allocation (+ time-units current-offerings))
  )
    (asserts! (> time-units u0) error-invalid-time-allocation)
    (asserts! (> neuron-price u0) error-invalid-neuron-valuation)
    (asserts! (>= available-resources updated-allocation) error-insufficient-neurons)
    (try! (modify-network-capacity (to-int time-units)))
    (map-set neural-resource-offerings {entity: tx-sender} 
             {time-allocation: updated-allocation, neural-price: neuron-price})
    (ok true)))

;; Retract resources from the neural marketplace
(define-public (retract-cognitive-offering (time-units uint))
  (let (
    (current-offering (get time-allocation (default-to {time-allocation: u0, neural-price: u0} 
                                        (map-get? neural-resource-offerings {entity: tx-sender}))))
  )
    (asserts! (>= current-offering time-units) error-insufficient-neurons)
    (try! (modify-network-capacity (to-int (- time-units))))
    (map-set neural-resource-offerings {entity: tx-sender} 
             {time-allocation: (- current-offering time-units), 
              neural-price: (get neural-price (default-to {time-allocation: u0, neural-price: u0} 
                                           (map-get? neural-resource-offerings {entity: tx-sender})))})
    (ok true)))

;; Execute direct neural resource acquisition
(define-public (acquire-neural-resources (contributor principal) (time-units uint))
  (let (
    (offering-details (default-to {time-allocation: u0, neural-price: u0} 
                     (map-get? neural-resource-offerings {entity: contributor})))
    (exchange-value (* time-units (get neural-price offering-details)))
    (network-transmission-fee (calculate-network-fee exchange-value))
    (total-exchange-cost (+ exchange-value network-transmission-fee))
    (contributor-inventory (default-to u0 (map-get? cognitive-resource-inventory contributor)))
    (requester-tokens (default-to u0 (map-get? synaptic-token-reserves tx-sender)))
    (contributor-tokens (default-to u0 (map-get? synaptic-token-reserves contributor)))
  )
    (asserts! (not (is-eq tx-sender contributor)) error-dendrite-connection-refused)
    (asserts! (> time-units u0) error-invalid-time-allocation)
    (asserts! (>= (get time-allocation offering-details) time-units) error-insufficient-neurons)
    (asserts! (>= contributor-inventory time-units) error-insufficient-neurons)
    (asserts! (>= requester-tokens total-exchange-cost) error-insufficient-neurons)

    ;; Update contributor resource inventory
    (map-set cognitive-resource-inventory contributor (- contributor-inventory time-units))
    (map-set neural-resource-offerings {entity: contributor} 
             {time-allocation: (- (get time-allocation offering-details) time-units), 
              neural-price: (get neural-price offering-details)})

    ;; Process neural token exchange
    (map-set synaptic-token-reserves tx-sender (- requester-tokens total-exchange-cost))
    (map-set cognitive-resource-inventory tx-sender 
             (+ (default-to u0 (map-get? cognitive-resource-inventory tx-sender)) time-units))

    ;; Credit tokens to cognitive resource provider
    (map-set synaptic-token-reserves contributor (+ contributor-tokens exchange-value))

    ;; Record network transmission fee
    (map-set synaptic-token-reserves cerebral-overseer 
             (+ (default-to u0 (map-get? synaptic-token-reserves cerebral-overseer)) network-transmission-fee))

    (ok true)))

;; =============================================================================
;; CEREBRAL OVERSIGHT FUNCTIONS
;; =============================================================================

;; Adjust neural protocol parameters
;; Enables the cerebral overseer to fine-tune network parameters
;; @param new-base-value: revised baseline value for cognitive tokens
;; @param new-threshold: updated maximum cognitive units per participant
;; @param new-fee-rate: updated network transmission fee percentage
;; @param new-global-limit: revised systemic capacity boundary
(define-public (recalibrate-network-parameters 
                (new-base-value uint) 
                (new-threshold uint) 
                (new-fee-rate uint) 
                (new-global-limit uint))
  (begin
    (asserts! (is-eq tx-sender cerebral-overseer) error-unauthorized-synapse)
    (asserts! (<= new-fee-rate u100) error-invalid-parameter-structure)
    (asserts! (> new-base-value u0) error-invalid-neuron-valuation)
    (asserts! (> new-threshold u0) error-threshold-violation)
    (asserts! (>= new-global-limit (var-get neural-network-utilization)) error-network-saturation)

    (var-set synaptic-base-unit-value new-base-value)
    (var-set contributor-capacity-threshold new-threshold)
    (var-set neural-network-fee-rate new-fee-rate)
    (var-set collective-capacity-limit new-global-limit)

    (ok true)))

;; =============================================================================
;; COGNITIVE MERIT FRAMEWORK
;; =============================================================================

;; Submit cognitive merit assessment
;; Allows participants to quantify contributor effectiveness
;; @param contributor: the principal of the cognitive resource contributor
;; @param merit-score: the quantified assessment value (1-5)
(define-public (register-cognitive-merit (contributor principal) (merit-score uint))
  (let (
    (assessor tx-sender)
    (prior-assessment (default-to u0 (map-get? synapse-merit-records 
                                   {cortex-contributor: contributor, assessor: assessor})))
    (assessment-tally (default-to u0 (map-get? merit-assessment-counts contributor)))
    (aggregate-score (default-to u0 (map-get? cumulative-merit-points contributor)))
    (updated-tally (if (is-eq prior-assessment u0) (+ assessment-tally u1) assessment-tally))
    (updated-aggregate (+ (- aggregate-score prior-assessment) merit-score))
  )
    (asserts! (not (is-eq assessor contributor)) error-dendrite-connection-refused)
    (asserts! (and (>= merit-score u1) (<= merit-score u5)) error-magnitude-outside-parameters)

    ;; Update cognitive merit records
    (map-set synapse-merit-records {cortex-contributor: contributor, assessor: assessor} merit-score)
    (map-set merit-assessment-counts contributor updated-tally)
    (map-set cumulative-merit-points contributor updated-aggregate)

    (ok true)))

;; =============================================================================
;; STRUCTURED EXCHANGE PROPOSAL SYSTEM
;; =============================================================================

;; Initiate structured neural resource exchange request
;; Creates a formal neural exchange proposal between participants
;; @param contributor: principal of the cognitive resource provider
;; @param time-units: requested cognitive resource time allocation
;; @param proposed-value: neuron exchange rate offered
(define-public (propose-neural-exchange (contributor principal) (time-units uint) (proposed-value uint))
  (let (
    (requester tx-sender)
    (request-id (var-get request-sequence-tracker))
    (offering-details (default-to {time-allocation: u0, neural-price: u0} 
                     (map-get? neural-resource-offerings {entity: contributor})))
    (exchange-value (* time-units proposed-value))
    (network-fee (calculate-network-fee exchange-value))
    (total-neuron-cost (+ exchange-value network-fee))
    (requester-balance (default-to u0 (map-get? synaptic-token-reserves requester)))
  )
    (asserts! (not (is-eq requester contributor)) error-dendrite-connection-refused)
    (asserts! (> time-units u0) error-invalid-time-allocation)
    (asserts! (>= (get time-allocation offering-details) time-units) error-insufficient-neurons)
    (asserts! (> proposed-value u0) error-invalid-neuron-valuation)
    (asserts! (>= requester-balance total-neuron-cost) error-insufficient-neurons)

    ;; Register the neural exchange request
    (map-set neural-exchange-requests
      {request-sequence: request-id}
      {
        requester: requester,
        contributor: contributor,
        time-units: time-units,
        neuron-value: proposed-value,
        phase: u0, ;; pending neural response
        neural-timestamp: block-height
      }
    )

    ;; Reserve neurons for the exchange
    (map-set synaptic-token-reserves requester (- requester-balance total-neuron-cost))

    ;; Increment sequence tracker
    (var-set request-sequence-tracker (+ request-id u1))

    (ok request-id)))

;; =============================================================================
;; PARTICIPANT REGISTRATION FUNCTIONS
;; =============================================================================

;; Register cognitive resource capacity
;; Enables participants to declare cognitive units available for exchange
;; @param time-units: cognitive time units to register
(define-public (register-cognitive-capacity (time-units uint))
  (let (
    (current-capacity (default-to u0 (map-get? cognitive-resource-inventory tx-sender)))
    (maximum-threshold (var-get contributor-capacity-threshold))
    (updated-capacity (+ current-capacity time-units))
  )
    (asserts! (> time-units u0) error-invalid-time-allocation)
    (asserts! (<= updated-capacity maximum-threshold) error-allocation-limit-exceeded)
    (map-set cognitive-resource-inventory tx-sender updated-capacity)
    (ok updated-capacity)))

;; =============================================================================
;; NEURAL TOKEN OPERATIONS
;; =============================================================================

;; Add neural tokens to participant reserve
;; Enables participants to deposit tokens for future cognitive exchanges
;; @param neuron-quantity: token amount to contribute
(define-public (contribute-neural-tokens (neuron-quantity uint))
  (let (
    (participant tx-sender)
    (current-reserve (default-to u0 (map-get? synaptic-token-reserves participant)))
    (updated-reserve (+ current-reserve neuron-quantity))
  )
    (asserts! (> neuron-quantity u0) error-null-transmission-rejected)
    (try! (stx-transfer? neuron-quantity participant (as-contract tx-sender)))
    (map-set synaptic-token-reserves participant updated-reserve)
    (ok updated-reserve)))

;; =============================================================================
;; PROTOCOL STATUS QUERIES
;; =============================================================================

;; Query participant cognitive capacity information
;; @param entity: principal whose resources should be checked
;; @returns: current capacity in time units or zero if not registered
(define-read-only (query-cognitive-capacity (entity principal))
  (default-to u0 (map-get? cognitive-resource-inventory entity)))

;; Query participant neural token reserve
;; @param entity: principal whose token balance should be checked
;; @returns: current neural token balance or zero if not registered
(define-read-only (query-neural-tokens (entity principal))
  (default-to u0 (map-get? synaptic-token-reserves entity)))

;; Query neural exchange request details
;; @param request-id: identifier of the request to check
;; @returns: request details or error if not found
(define-read-only (query-exchange-request (request-id uint))
  (let ((request-data (map-get? neural-exchange-requests {request-sequence: request-id})))
    (asserts! (not (is-eq request-data none)) error-invalid-parameter-structure)
    (ok request-data)))

;; Query participant cognitive merit score
;; @param contributor: principal whose merit should be evaluated
;; @returns: average merit score or zero if not assessed
(define-read-only (query-cognitive-merit (contributor principal))
  (let (
    (assessment-count (default-to u0 (map-get? merit-assessment-counts contributor)))
    (total-points (default-to u0 (map-get? cumulative-merit-points contributor)))
  )
    (if (> assessment-count u0)
        (ok (/ total-points assessment-count))
        (ok u0))))


