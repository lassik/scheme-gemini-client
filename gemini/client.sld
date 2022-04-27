(define-library (gemini client)
  (export gemini-get)
  (import (scheme base) (gemini))
  (cond-expand
    (chicken
     (import (chicken condition) (openssl) (uri-generic))))
  (begin

    (define (write-request to-server uri-string)
      (write-string (string-append uri-string "\r\n") to-server))

    (define (read-response from-server)
      (let ((line (read-cr-lf-terminated-line from-server)))
        (if (or (< (string-length line) 3)
                (not (char<=? #\0 (string-ref line 0) #\9))
                (not (char<=? #\0 (string-ref line 1) #\9))
                (not (char=? #\space (string-ref line 2))))
            (error "Malformed first line" line)
            (let ((code (string->number (string-copy line 0 2)))
                  (meta (string-copy line 3 (string-length line))))
              (make-gemini-response code meta from-server)))))

    (define (gemini-get uri handle-response)
      (let* ((uri-object (uri-reference uri))
             (uri-string (if (string? uri) uri (uri->string uri-object))))
        (unless (eq? 'gemini (uri-scheme uri-object))
          (error "Not a gemini URI" uri))
        (let-values (((from-server to-server)
                      (ssl-connect* hostname: (uri-host uri-object)
                                    port: (or (uri-port uri-object) 1965)
                                    verify?: #f
                                    protocol: (cons 'tlsv12 ssl-max-protocol))))
          (dynamic-wind (lambda () #f)
                        (lambda ()
                          (write-request to-server uri-string)
                          (handle-response (read-response from-server)))
                        (lambda ()
                          (close-input-port from-server)
                          (close-output-port to-server))))))))
