;; Best Practice Contract
;; Shares quality improvement techniques across the network

(define-data-var admin principal tx-sender)

;; Best practices map
(define-map best-practices
  { practice-id: (string-utf8 36) }
  {
    title: (string-utf8 100),
    description: (string-utf8 1000),
    contributor: principal,
    submission-date: uint,
    industry: (string-utf8 50),
    category: (string-utf8 50),
    status: uint, ;; 0 = submitted, 1 = approved, 2 = featured, 3 = archived
    votes: uint
  }
)

;; Votes tracking to prevent double voting
(define-map votes
  { practice-id: (string-utf8 36), voter: principal }
  { voted: bool }
)

;; Submit a new best practice
(define-public (submit-best-practice
  (practice-id (string-utf8 36))
  (title (string-utf8 100))
  (description (string-utf8 1000))
  (industry (string-utf8 50))
  (category (string-utf8 50)))
  (let ((sender tx-sender))
    (if (map-insert best-practices
          { practice-id: practice-id }
          {
            title: title,
            description: description,
            contributor: sender,
            submission-date: block-height,
            industry: industry,
            category: category,
            status: u0, ;; Submitted by default
            votes: u0
          })
        (ok true)
        (err u1)) ;; Practice ID already exists
  )
)

;; Approve a best practice (admin only)
(define-public (approve-best-practice (practice-id (string-utf8 36)))
  (let ((practice (unwrap! (map-get? best-practices { practice-id: practice-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq sender (var-get admin))
      (begin
        (map-set best-practices
          { practice-id: practice-id }
          (merge practice { status: u1 }))
        (ok true))
      (err u3)) ;; Not admin
  )
)

;; Feature a best practice (admin only)
(define-public (feature-best-practice (practice-id (string-utf8 36)))
  (let ((practice (unwrap! (map-get? best-practices { practice-id: practice-id }) (err u2)))
        (sender tx-sender))
    (if (is-eq sender (var-get admin))
      (begin
        (map-set best-practices
          { practice-id: practice-id }
          (merge practice { status: u2 }))
        (ok true))
      (err u3)) ;; Not admin
  )
)

;; Archive a best practice (admin or contributor)
(define-public (archive-best-practice (practice-id (string-utf8 36)))
  (let ((practice (unwrap! (map-get? best-practices { practice-id: practice-id }) (err u2)))
        (sender tx-sender))
    (if (or (is-eq sender (get contributor practice)) (is-eq sender (var-get admin)))
      (begin
        (map-set best-practices
          { practice-id: practice-id }
          (merge practice { status: u3 }))
        (ok true))
      (err u4)) ;; Not authorized
  )
)

;; Vote for a best practice (one vote per practice per user)
(define-public (vote-for-practice (practice-id (string-utf8 36)))
  (let ((practice (unwrap! (map-get? best-practices { practice-id: practice-id }) (err u2)))
        (sender tx-sender)
        (has-voted (default-to { voted: false } (map-get? votes { practice-id: practice-id, voter: sender }))))
    (if (get voted has-voted)
      (err u5) ;; Already voted
      (begin
        (map-set votes
          { practice-id: practice-id, voter: sender }
          { voted: true })
        (map-set best-practices
          { practice-id: practice-id }
          (merge practice { votes: (+ (get votes practice) u1) }))
        (ok true))
    )
  )
)

;; Read-only function to get best practice details
(define-read-only (get-best-practice (practice-id (string-utf8 36)))
  (map-get? best-practices { practice-id: practice-id })
)

;; Read-only function to check if a user has voted for a practice
(define-read-only (has-voted-for-practice (practice-id (string-utf8 36)) (voter principal))
  (default-to false (get voted (map-get? votes { practice-id: practice-id, voter: voter })))
)

;; Read-only function to check if a practice is approved
(define-read-only (is-practice-approved (practice-id (string-utf8 36)))
  (let ((practice (default-to { status: u0 } (map-get? best-practices { practice-id: practice-id }))))
    (>= (get status practice) u1)
  )
)
