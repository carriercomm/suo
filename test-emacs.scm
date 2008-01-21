(define pending-events '())

(define (read-one)
  (let ((form (read)))
    (if (eof-object? form)
	(exit 0))
    (cond ((and (pair? form) (eq? (car form) 'event))
	   (set! pending-events (append pending-events (list (cdr form))))
	   #f)
	  (else
	   form))))

(define (read-response)
  (or (read-one)
      (read-response)))
	
(define (do-request req)
  (write req)
  (newline)
  (let ((res (read-response)))
    (if (and (pair? res) (eq? (car res) 'error))
	(begin 
	  (pk res)
	  (exit))     
	res)))

(define (event-loop)
  (if (null? pending-events)
      (let ((res (read-one)))
	(if res
	    (begin
	      (display ";; unexpected response ")
	      (write res)
	      (newline)))
	(event-loop))
      (let ((ev (car pending-events)))
	(set! pending-events (cdr pending-events))
	(handle-event ev)
	(event-loop))))

(define event-handlers (make-hash-table))

(define (register-handler id tag handler)
  (hash-set! event-handlers (list id tag) handler))

(define (handle-event ev)
  (pk ev)
  (let ((handler (hash-ref event-handlers ev)))
    (if handler
	(handler)
	(let ((handler (hash-ref event-handlers (car ev))))
	  (if handler
	      (handler (cadr ev)))))))

(define (create-buffer name)
  (do-request `(create-buffer ,name)))

(define (show-buffer buffer)
  (do-request `(show-buffer ,buffer)))

(define (create-segment buffer pos props)
  (do-request `(create-segment ,buffer ,pos ,props)))

(define (hide-segment seg)
  (do-request `(hide-segment ,seg)))

(define (show-segment seg)
  (do-request `(show-segment ,seg)))

(define (goto-segment seg)
  (do-request `(goto-segment ,seg)))

(define (set-text segment text)
  (do-request `(set-text ,segment ,text)))

(define (append-text segment text)
  (do-request `(append-text ,segment ,text)))

(define (clear-dirty segment)
  (do-request `(clear-dirty ,segment)))

(define (get-text segment)
  (do-request `(get-text ,segment)))

(define (define-key segment key handler)
  (do-request `(define-key ,segment ,key))
  (register-handler segment key handler))

(define (emacs-repl)
  (let* ((buffer     (create-buffer "*suo-repl*"))
	 (transcript (create-segment buffer 0 '(read-only t)))
	 (ts-empty   #t)
	 (cmdline    (create-segment buffer 1 '()))
	 (alertbox   (create-segment buffer 2 '(read-only t))))

    (define (alert msg)
      (set-text alertbox msg)
      (clear-dirty cmdline))

    (define (dirty)
      (set-text alertbox ""))

    (define (submit)
      (let ((text `(text ,(get-text cmdline) face bold)))
	(cond (ts-empty
	       (append-text transcript text)
	       (show-segment transcript)
	       (set! ts-empty #f))
	      (else
	       (append-text transcript `(seq "\n" ,text))))
	(set-text cmdline "")
	(alert "done")))
      
    (define-key cmdline "RET" submit)
    (register-handler cmdline 'dirty dirty)

    (hide-segment transcript)
    (goto-segment cmdline)
    (show-buffer buffer)
    (event-loop)))

(emacs-repl)