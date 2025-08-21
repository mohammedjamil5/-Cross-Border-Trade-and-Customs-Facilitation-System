;; Trade Documentation Contract
;; Manages import/export documentation and verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DOCUMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-DOCUMENT-EXISTS (err u103))

;; Data Variables
(define-data-var next-document-id uint u1)

;; Data Maps
(define-map trade-documents
  { document-id: uint }
  {
    document-type: (string-ascii 50),
    document-hash: (buff 32),
    submitter: principal,
    status: (string-ascii 20),
    jurisdiction: (string-ascii 50),
    created-at: uint,
    verified-at: (optional uint),
    verifier: (optional principal)
  }
)

(define-map document-amendments
  { document-id: uint, amendment-id: uint }
  {
    amendment-hash: (buff 32),
    reason: (string-ascii 200),
    amended-by: principal,
    amended-at: uint
  }
)

;; Public Functions

;; Submit a new trade document
(define-public (submit-document (document-type (string-ascii 50)) (document-hash (buff 32)) (jurisdiction (string-ascii 50)))
  (let ((document-id (var-get next-document-id)))
    (asserts! (is-none (map-get? trade-documents { document-id: document-id })) ERR-DOCUMENT-EXISTS)
    (map-set trade-documents
      { document-id: document-id }
      {
        document-type: document-type,
        document-hash: document-hash,
        submitter: tx-sender,
        status: "pending",
        jurisdiction: jurisdiction,
        created-at: block-height,
        verified-at: none,
        verifier: none
      }
    )
    (var-set next-document-id (+ document-id u1))
    (ok document-id)
  )
)

;; Verify a trade document
(define-public (verify-document (document-id uint))
  (let ((document (unwrap! (map-get? trade-documents { document-id: document-id }) ERR-DOCUMENT-NOT-FOUND)))
    (asserts! (is-eq (get status document) "pending") ERR-INVALID-STATUS)
    (map-set trade-documents
      { document-id: document-id }
      (merge document {
        status: "verified",
        verified-at: (some block-height),
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Reject a trade document
(define-public (reject-document (document-id uint))
  (let ((document (unwrap! (map-get? trade-documents { document-id: document-id }) ERR-DOCUMENT-NOT-FOUND)))
    (asserts! (is-eq (get status document) "pending") ERR-INVALID-STATUS)
    (map-set trade-documents
      { document-id: document-id }
      (merge document {
        status: "rejected",
        verified-at: (some block-height),
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Amend a document
(define-public (amend-document (document-id uint) (amendment-id uint) (amendment-hash (buff 32)) (reason (string-ascii 200)))
  (let ((document (unwrap! (map-get? trade-documents { document-id: document-id }) ERR-DOCUMENT-NOT-FOUND)))
    (asserts! (is-eq (get submitter document) tx-sender) ERR-NOT-AUTHORIZED)
    (map-set document-amendments
      { document-id: document-id, amendment-id: amendment-id }
      {
        amendment-hash: amendment-hash,
        reason: reason,
        amended-by: tx-sender,
        amended-at: block-height
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get document details
(define-read-only (get-document (document-id uint))
  (map-get? trade-documents { document-id: document-id })
)

;; Get document amendment
(define-read-only (get-amendment (document-id uint) (amendment-id uint))
  (map-get? document-amendments { document-id: document-id, amendment-id: amendment-id })
)

;; Check if document is verified
(define-read-only (is-document-verified (document-id uint))
  (match (map-get? trade-documents { document-id: document-id })
    document (is-eq (get status document) "verified")
    false
  )
)
