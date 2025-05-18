;; Facility Verification Contract
;; Validates production sites in the manufacturing network

(define-data-var admin principal tx-sender)

;; Facility status: 0 = unverified, 1 = pending, 2 = verified, 3 = suspended
(define-map facilities
  { facility-id: (string-utf8 36) }
  {
    owner: principal,
    name: (string-utf8 100),
    location: (string-utf8 100),
    status: uint,
    verification-date: uint,
    verifier: principal
  }
)

;; List of authorized verifiers
(define-map verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Register a new facility (only unverified status)
(define-public (register-facility (facility-id (string-utf8 36)) (name (string-utf8 100)) (location (string-utf8 100)))
  (let ((sender tx-sender))
    (if (map-insert facilities
          { facility-id: facility-id }
          {
            owner: sender,
            name: name,
            location: location,
            status: u0,
            verification-date: u0,
            verifier: sender
          })
        (ok true)
        (err u1) ;; Facility ID already exists
    )
  )
)

;; Request verification for a facility
(define-public (request-verification (facility-id (string-utf8 36)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq (get owner facility) sender)
      (begin
        (map-set facilities
          { facility-id: facility-id }
          (merge facility { status: u1 })) ;; Set to pending
        (ok true))
      (err u3) ;; Not the facility owner
    )
  )
)

;; Verify a facility (only authorized verifiers)
(define-public (verify-facility (facility-id (string-utf8 36)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) (err u2)))
        (sender tx-sender)
        (is-verifier (default-to { authorized: false } (map-get? verifiers { verifier: sender }))))
    (if (get authorized is-verifier)
      (begin
        (map-set facilities
          { facility-id: facility-id }
          (merge facility {
            status: u2,
            verification-date: block-height,
            verifier: sender
          }))
        (ok true))
      (err u4) ;; Not an authorized verifier
    )
  )
)

;; Add a verifier (admin only)
(define-public (add-verifier (verifier principal))
  (let ((sender tx-sender))
    (if (is-eq sender (var-get admin))
      (begin
        (map-set verifiers { verifier: verifier } { authorized: true })
        (ok true))
      (err u5) ;; Not admin
    )
  )
)

;; Suspend a facility (admin or verifier only)
(define-public (suspend-facility (facility-id (string-utf8 36)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) (err u2)))
        (sender tx-sender)
        (is-verifier (default-to { authorized: false } (map-get? verifiers { verifier: sender }))))
    (if (or (is-eq sender (var-get admin)) (get authorized is-verifier))
      (begin
        (map-set facilities
          { facility-id: facility-id }
          (merge facility { status: u3 }))
        (ok true))
      (err u6) ;; Not authorized to suspend
    )
  )
)

;; Read-only function to get facility details
(define-read-only (get-facility (facility-id (string-utf8 36)))
  (map-get? facilities { facility-id: facility-id })
)

;; Read-only function to check if a principal is a verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (get authorized (map-get? verifiers { verifier: verifier })))
)
