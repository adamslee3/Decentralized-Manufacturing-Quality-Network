;; Standard Registration Contract
;; Records quality requirements for manufacturing

(define-data-var admin principal tx-sender)

;; Standards map
(define-map standards
  { standard-id: (string-utf8 36) }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    version: (string-utf8 20),
    creator: principal,
    creation-date: uint,
    status: uint, ;; 0 = draft, 1 = active, 2 = deprecated
    industry: (string-utf8 50)
  }
)

;; Requirements for each standard
(define-map standard-requirements
  { standard-id: (string-utf8 36), requirement-id: (string-utf8 36) }
  {
    description: (string-utf8 500),
    mandatory: bool,
    verification-method: (string-utf8 100)
  }
)

;; Register a new standard
(define-public (register-standard
  (standard-id (string-utf8 36))
  (name (string-utf8 100))
  (description (string-utf8 500))
  (version (string-utf8 20))
  (industry (string-utf8 50)))
  (let ((sender tx-sender))
    (if (map-insert standards
          { standard-id: standard-id }
          {
            name: name,
            description: description,
            version: version,
            creator: sender,
            creation-date: block-height,
            status: u0, ;; Draft by default
            industry: industry
          })
        (ok true)
        (err u1) ;; Standard ID already exists
    )
  )
)

;; Add a requirement to a standard
(define-public (add-requirement
  (standard-id (string-utf8 36))
  (requirement-id (string-utf8 36))
  (description (string-utf8 500))
  (mandatory bool)
  (verification-method (string-utf8 100)))
  (let ((standard (unwrap! (map-get? standards { standard-id: standard-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq (get creator standard) sender)
      (if (map-insert standard-requirements
            { standard-id: standard-id, requirement-id: requirement-id }
            {
              description: description,
              mandatory: mandatory,
              verification-method: verification-method
            })
          (ok true)
          (err u3)) ;; Requirement ID already exists for this standard
      (err u4) ;; Not the standard creator
    )
  )
)

;; Activate a standard (change status from draft to active)
(define-public (activate-standard (standard-id (string-utf8 36)))
  (let ((standard (unwrap! (map-get? standards { standard-id: standard-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq (get creator standard) sender)
      (begin
        (map-set standards
          { standard-id: standard-id }
          (merge standard { status: u1 }))
        (ok true))
      (err u4) ;; Not the standard creator
    )
  )
)

;; Deprecate a standard
(define-public (deprecate-standard (standard-id (string-utf8 36)))
  (let ((standard (unwrap! (map-get? standards { standard-id: standard-id }) (err u2)))
        (sender tx-sender))
    (if (or (is-eq (get creator standard) sender) (is-eq sender (var-get admin)))
      (begin
        (map-set standards
          { standard-id: standard-id }
          (merge standard { status: u2 }))
        (ok true))
      (err u4) ;; Not authorized
    )
  )
)

;; Read-only function to get standard details
(define-read-only (get-standard (standard-id (string-utf8 36)))
  (map-get? standards { standard-id: standard-id })
)

;; Read-only function to get requirement details
(define-read-only (get-requirement (standard-id (string-utf8 36)) (requirement-id (string-utf8 36)))
  (map-get? standard-requirements { standard-id: standard-id, requirement-id: requirement-id })
)

;; Read-only function to check if a standard is active
(define-read-only (is-standard-active (standard-id (string-utf8 36)))
  (let ((standard (default-to { status: u0 } (map-get? standards { standard-id: standard-id }))))
    (is-eq (get status standard) u1)
  )
)
