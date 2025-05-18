;; Testing Protocol Contract
;; Manages quality verification procedures

(define-data-var admin principal tx-sender)

;; Testing protocols
(define-map protocols
  { protocol-id: (string-utf8 36) }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    creator: principal,
    creation-date: uint,
    standard-id: (string-utf8 36),
    version: (string-utf8 20),
    status: uint ;; 0 = draft, 1 = active, 2 = deprecated
  }
)

;; Protocol steps
(define-map protocol-steps
  { protocol-id: (string-utf8 36), step-id: (string-utf8 36) }
  {
    description: (string-utf8 500),
    order: uint,
    expected-result: (string-utf8 200),
    tools-required: (string-utf8 200)
  }
)

;; Test results
(define-map test-results
  { test-id: (string-utf8 36) }
  {
    protocol-id: (string-utf8 36),
    facility-id: (string-utf8 36),
    tester: principal,
    test-date: uint,
    product-batch: (string-utf8 100),
    passed: bool,
    notes: (string-utf8 500)
  }
)

;; Register a new testing protocol
(define-public (register-protocol
  (protocol-id (string-utf8 36))
  (name (string-utf8 100))
  (description (string-utf8 500))
  (standard-id (string-utf8 36))
  (version (string-utf8 20)))
  (let ((sender tx-sender))
    (if (map-insert protocols
          { protocol-id: protocol-id }
          {
            name: name,
            description: description,
            creator: sender,
            creation-date: block-height,
            standard-id: standard-id,
            version: version,
            status: u0 ;; Draft by default
          })
        (ok true)
        (err u1) ;; Protocol ID already exists
    )
  )
)

;; Add a step to a protocol
(define-public (add-protocol-step
  (protocol-id (string-utf8 36))
  (step-id (string-utf8 36))
  (description (string-utf8 500))
  (order uint)
  (expected-result (string-utf8 200))
  (tools-required (string-utf8 200)))
  (let ((protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq (get creator protocol) sender)
      (if (map-insert protocol-steps
            { protocol-id: protocol-id, step-id: step-id }
            {
              description: description,
              order: order,
              expected-result: expected-result,
              tools-required: tools-required
            })
          (ok true)
          (err u3)) ;; Step ID already exists for this protocol
      (err u4) ;; Not the protocol creator
    )
  )
)

;; Activate a protocol
(define-public (activate-protocol (protocol-id (string-utf8 36)))
  (let ((protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq (get creator protocol) sender)
      (begin
        (map-set protocols
          { protocol-id: protocol-id }
          (merge protocol { status: u1 }))
        (ok true))
      (err u4) ;; Not the protocol creator
    )
  )
)

;; Record a test result
(define-public (record-test-result
  (test-id (string-utf8 36))
  (protocol-id (string-utf8 36))
  (facility-id (string-utf8 36))
  (product-batch (string-utf8 100))
  (passed bool)
  (notes (string-utf8 500)))
  (let ((sender tx-sender)
        (protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) (err u2))))
    ;; Check if protocol is active
    (if (is-eq (get status protocol) u1)
      (if (map-insert test-results
            { test-id: test-id }
            {
              protocol-id: protocol-id,
              facility-id: facility-id,
              tester: sender,
              test-date: block-height,
              product-batch: product-batch,
              passed: passed,
              notes: notes
            })
          (ok true)
          (err u5)) ;; Test ID already exists
      (err u6) ;; Protocol not active
    )
  )
)

;; Read-only function to get protocol details
(define-read-only (get-protocol (protocol-id (string-utf8 36)))
  (map-get? protocols { protocol-id: protocol-id })
)

;; Read-only function to get protocol step
(define-read-only (get-protocol-step (protocol-id (string-utf8 36)) (step-id (string-utf8 36)))
  (map-get? protocol-steps { protocol-id: protocol-id, step-id: step-id })
)

;; Read-only function to get test result
(define-read-only (get-test-result (test-id (string-utf8 36)))
  (map-get? test-results { test-id: test-id })
)
