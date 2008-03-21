;;; -*- mode: Lisp; Syntax: Common-Lisp; -*-
;;;
;;; Copyright (c) 2008 by the authors.
;;;
;;; See COPYING for details.

(in-package :cl-walker-test)

(defsuite* (walk-unwalk :in test))

(deftest check-walk-unwalk (form &optional (expected form))
  (let ((walked-form (unwalk-form (walk-form form))))
    (is (equal walked-form expected))))

(defmacro define-walk-unwalk-test (name &body body)
  `(deftest ,name ()
     ,@(loop
          :for entry :in body
          :collect (if (and (consp entry)
                            (eq (first entry) 'with-expected-failures))
                       `(with-expected-failures
                          ,@(mapcar (lambda (entry)
                                      `(check-walk-unwalk ',entry))
                                    (rest entry)))
                       `(check-walk-unwalk ',entry)))))

(define-walk-unwalk-test test/constant
  1 'a "a" (1 2 3) #(1 2 3))

(define-walk-unwalk-test test/variable
  var)

(define-walk-unwalk-test test/application
  (* 2 3)
  (+ (* 3 3) (* 4 4)))

(define-walk-unwalk-test test/lambda-application
  ((lambda (x) (x x))
   #'(lambda (x) (x x)))
  ((lambda (x k) (k x))
   (if p x y)
   id))

(define-walk-unwalk-test test/declare/1
  (locally (declare (ignorable a) (ignorable b)))
  (with-expected-failures
    (locally (declare (zork)))
    (locally (declare (ignorable a b)))))

(deftest test/declare/2 ()
  (check-walk-unwalk
   '(lambda () (declare))
   '#'(lambda ()))
  (with-expected-failures
    (check-walk-unwalk
     '(lambda () (declare (ignorable)))
     '#'(lambda ()))))

;; TODO fix the last test, &optional is misplaced and should signal an error
(define-walk-unwalk-test test/lambda-function
  #'(lambda (x y) (y x))
  #'(lambda (x &key y z) (z (y x)))
  #'(lambda (&optional port) (close port))
  #'(lambda (x &rest args) (apply x args))
  #'(lambda (object &key a &allow-other-keys) (values))
  #'(lambda (&rest args &key a b &optional x &allow-other-keys) 2))

(define-walk-unwalk-test test/walk-unwalk/block
  (block label (get-up) (eat-food) (go-to-sleep))
  (block label ((lambda (f x) (f (f x))) #'car))
  (block label (reachable) (return-from label 'done) (unreachable)))

(define-walk-unwalk-test test/walk-unwalk/catch
  (catch 'done (with-call/cc* (* 2 3)))
  (catch 'scheduler
    (tagbody start
       (funcall thunk)
       (if (done-p) (throw 'scheduler 'done) (go start))))
  (catch 'c
    (flet ((c1 () (throw 'c 1)))
      (catch 'c (c1) (print 'unreachable))
      2)))

(define-walk-unwalk-test test/walk-unwalk/if
  (if p x y)
  (if (pred x) (f x) (f-tail y #(1 2 3))))

(define-walk-unwalk-test test/walk-unwalk/flet
  (flet ((sq (x)
           (* x x)))
    (+ (sq 3) (sq 4)))
  (flet ((prline (s)
           (princ s)
           (terpri)))
    (prline "hello")
    (prline "world")))

(define-walk-unwalk-test test/walk-unwalk/labels
  (labels ((fac-acc (n acc)
             (if (zerop n)
                 (land acc)
                 (bounce
                  (fac-acc (1- n) (* n acc))))))
    (fac-acc (fac-acc 10 1) 1))
  (labels ((evenp (n)
             (if (zerop n) t (oddp (1- n))))
           (oddp (n)
             (if (zerop n) nil (evenp (1- n)))))
    (oddp 666)))

(define-walk-unwalk-test test/walk-unwalk/let
  (let ((a 2) (b 3) (c 4))
    (+ (- a b) (- b c) (- c a)))
  (let ((a b) (b a)) (format t "side-effect~%") (f a b)))

(define-walk-unwalk-test test/walk-unwalk/let*
  (let* ((a (random 100)) (b (* a a))) (- b a))
  (let* ((a b) (b a)) (equal a b)))

(define-walk-unwalk-test test/walk-unwalk/load-time-value
  (load-time-value *load-pathname* nil))

(define-walk-unwalk-test test/walk-unwalk/locally
  (locally (setq *global* (whoops))))

(define-walk-unwalk-test test/walk-unwalk/multiple-value-call
  (multiple-value-call #'list 1 '/ (values 2 3) '/ (values) '/ (floor 2.5))
  (multiple-value-call #'+ (floor 5 3) (floor 19 4)))

(define-walk-unwalk-test test/walk-unwalk/multiple-value-prog1
  (multiple-value-prog1
      (values-list temp)
    (setq temp nil)
    (values-list temp)))

(define-walk-unwalk-test test/walk-unwalk/progn
  (progn (f a) (f-tail b) c)
  (progn #'(lambda (x) (x x)) 2 'a))

(define-walk-unwalk-test test/walk-unwalk/progv
  (progv '(*x*) '(2) *x*))

(define-walk-unwalk-test test/walk-unwalk/setq
  (setq x '(2 #(3 5 7) 11 "13" '17))
  (setq *global* 'symbol))

(define-walk-unwalk-test test/walk-unwalk/tagbody
  (tagbody
     (setq val 1)
     (go point-a)
     (setq val (+ val 16))
   point-c
     (setq val (+ val 4))
     (go point-b)
     (setq val (+ val 32))
   point-a
     (setq val (+ val 2))
     (go point-c)
     (setq val (+ val 64))
   point-b
     (setq val (+ val 8)))
  (tagbody
     (setq n (f2 flag #'(lambda () (go out))))
   out
     (prin1 n)))

(define-walk-unwalk-test test/walk-unwalk/the
  (the number (reverse "naoh"))
  (the string 1))

(define-walk-unwalk-test test/walk-unwalk/unwind-protect
  (unwind-protect
       (progn (setq count (+ count 1))
              (perform-access))
    (setq count (- count 1)))
  (unwind-protect
       (progn (with-call/cc* (walk-the-plank))
              (pushed-off-the-plank))
    (save-life)))

