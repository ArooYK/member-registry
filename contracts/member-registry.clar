;; ------------------------------------------------------------
;; member-registry.clar
;; STX-compatible DAO member registry
;; ------------------------------------------------------------

(define-constant ERR-NOT-GOVERNANCE u100)
(define-constant ERR-ALREADY-MEMBER u101)
(define-constant ERR-NOT-MEMBER u102)
(define-constant ERR-INVALID u103)

;; ------------------------------------------------------------
;; Governance authority
;; ------------------------------------------------------------

(define-data-var governance (optional principal) none)

;; ------------------------------------------------------------
;; Member storage
;; ------------------------------------------------------------

(define-map members
  {user: principal}
  {active: bool, joined-at: uint, role: uint}
)

(define-data-var member-count uint u0)

;; ------------------------------------------------------------
;; Initialization (one-time)
;; ------------------------------------------------------------

(define-public (initialize (governance-contract principal) (admin principal))
  (begin
    (asserts! (and (not (is-eq governance-contract tx-sender)) (not (is-eq admin tx-sender))) (err ERR-INVALID))
    (match (var-get governance)
      existing (err ERR-INVALID)
      (begin
        (var-set governance (some governance-contract))
        (map-set members
          { user: admin }
          {
            active: true,
            joined-at: burn-block-height,
            role: u2
          }
        )
        (var-set member-count u1)
        (ok admin)
      )
    )
  )
)

;; ------------------------------------------------------------
;; Internal governance check
;; ------------------------------------------------------------

(define-private (is-governance)
  (match (var-get governance)
    gov-contract (is-eq gov-contract tx-sender)
    false
  )
)

;; ------------------------------------------------------------
;; Add member
;; ------------------------------------------------------------

(define-public (add-member (user principal) (role uint))
  (begin
    (asserts! (and (not (is-eq user tx-sender)) (>= role u0)) (err ERR-INVALID))
    (if (not (is-governance))
        (err ERR-NOT-GOVERNANCE)
        (match (map-get? members { user: user })
          existing (err ERR-ALREADY-MEMBER)
          (begin
            (map-set members
              { user: user }
              {
                active: true,
                joined-at: burn-block-height,
                role: role
              }
            )
            (var-set member-count (+ (var-get member-count) u1))
            (ok true)
          )
        )
    )
  )
)

;; ------------------------------------------------------------
;; Remove member
;; ------------------------------------------------------------

(define-public (remove-member (user principal))
  (begin
    (asserts! (not (is-eq user tx-sender)) (err ERR-INVALID))
    (if (not (is-governance))
        (err ERR-NOT-GOVERNANCE)
        (match (map-get? members { user: user })
          entry (err ERR-NOT-MEMBER)
          (begin
            (map-delete members { user: user })
            (var-set member-count (- (var-get member-count) u1))
            (ok true)
          )
        )
    )
  )
)

;; ------------------------------------------------------------
;; Update member role
;; ------------------------------------------------------------

(define-public (set-role (user principal) (role uint))
  (begin
    (asserts! (and (not (is-eq user tx-sender)) (>= role u0)) (err ERR-INVALID))
    (if (not (is-governance))
        (err ERR-NOT-GOVERNANCE)
        (match (map-get? members { user: user })
          m (begin
            (map-set members
              { user: user }
              {
                active: true,
                joined-at: (get joined-at m),
                role: role
              }
            )
            (ok role)
          )
          (err ERR-NOT-MEMBER)
        )
    )
  )
)

;; ------------------------------------------------------------
;; Deactivate member (soft remove)
;; ------------------------------------------------------------

(define-public (deactivate-member (user principal))
  (begin
    (asserts! (not (is-eq user tx-sender)) (err ERR-INVALID))
    (if (not (is-governance))
        (err ERR-NOT-GOVERNANCE)
        (match (map-get? members { user: user })
          m (begin
            (map-set members
              { user: user }
              {
                active: false,
                joined-at: (get joined-at m),
                role: (get role m)
              }
            )
            (ok true)
          )
          (err ERR-NOT-MEMBER)
        )
    )
  )
)

;; ------------------------------------------------------------
;; Read-only helpers
;; ------------------------------------------------------------

(define-read-only (is-member (user principal))
  (match (map-get? members { user: user })
    m (get active m)
    false
  )
)

(define-read-only (get-member (user principal))
  (map-get? members { user: user })
)

(define-read-only (get-role (user principal))
  (match (map-get? members { user: user })
    m (ok (get role m))
    (err ERR-NOT-MEMBER)
  )
)

(define-read-only (get-member-count)
  (ok (var-get member-count))
)
