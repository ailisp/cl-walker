;; -*- lisp -*-

(in-package :it.bese.arnesi)

;;;; * A Code UnWalker

;;; ** Public Entry Point

(defgeneric unwalk-form (form)
  (:documentation "Unwalk FORM and return a list representation."))

(defmacro defunwalker-handler (class (&rest slots) &body body)
  ;; We deliberately catch the variable `form' because sometimes its
  ;; useful when we need to call a method instead of getting a slot
  ;; value.
  `(progn
     (defmethod unwalk-form ((form ,class))
       (with-slots ,slots form
	 ,@body))
     ',class))

(declaim (inline unwalk-forms))
(defun unwalk-forms (forms)
  (mapcar #'unwalk-form forms))

;;;; Atoms

(defunwalker-handler constant-form (value)
  (typecase value
    (symbol `(quote ,value))
    (cons   `(quote ,value))
    (t value)))

(defunwalker-handler variable-reference (name)
  name)

;;;; Function Application

(defunwalker-handler application-form (operator arguments)
  (cons operator (unwalk-forms arguments)))

(defunwalker-handler lambda-application-form (operator arguments)
  (cons (unwalk-form operator) (unwalk-forms arguments)))

;;;; Functions

(defunwalker-handler lambda-function-form (arguments body)
  `(lambda ,(unwalk-arguments arguments) ,@(unwalk-forms body)))

(defunwalker-handler function-object-form (name)
  `(function ,name))

;;;; Arguments

(defun unwalk-arguments (arguments)
  (let (optional-p rest-p keyword-p)
    ;; Darling, what did you do with my monad?  Honey, don't worry too
    ;; much about lambda-list correctness.  Okay, well stated.
    (reduce #'append
	    (mapcar #'(lambda (form)
			(append
			 (typecase form
			   (optional-function-argument-form 
			    (unless optional-p (setf optional-p t) '(&optional)))
			   (rest-function-argument-form
			    (unless rest-p (setf rest-p t) '(&rest)))
			   (keyword-function-argument-form
			    (unless keyword-p (setf keyword-p t) '(&key))))
			 (list (unwalk-form form))))
		    arguments))))

(defunwalker-handler required-function-argument-form (name)
  name)

(defunwalker-handler specialized-function-argument-form (name specializer)
  (if (eq specializer t)
      name
      `(,name ,specializer)))

(defunwalker-handler optional-function-argument-form (name default-value supplied-p-parameter)
  (let ((default-value (unwalk-form default-value)))
    (cond ((and name default-value supplied-p-parameter)
	   `(,name ,default-value ,supplied-p-parameter))
	  ((and name default-value)
	   `(,name ,default-value))
	  (name name)
	  (t (error "Invalid optional argument ~A" form)))))

(defunwalker-handler keyword-function-argument-form (keyword-name name default-value supplied-p-parameter)
  (let ((default-value (unwalk-form default-value)))
    (cond ((and keyword-name name default-value supplied-p-parameter)
	   `((,keyword-name ,name) ,default-value ,supplied-p-parameter))
	  ((and name default-value supplied-p-parameter)
	   `(,name ,default-value ,supplied-p-parameter))
	  ((and name default-value)
	   `(,name ,default-value))
	  (name name)
	  (t (error "Invalid keyword argument ~A" form)))))

(defunwalker-handler allow-other-keys-function-argument-form ()
  '&allow-other-keys)

(defunwalker-handler rest-function-argument-form (name)
  name)

;;;; BLOCK/RETURN-FROM

(defunwalker-handler block-form (name body)
  `(block ,name ,@(unwalk-forms body)))

(defunwalker-handler return-from-form (target-block result)
  `(return-from ,(name target-block) ,(unwalk-form result)))

;;;; CATCH/THROW

(defunwalker-handler catch-form (tag body)
  `(catch ,(unwalk-form tag) ,@(unwalk-forms body)))

(defunwalker-handler throw-form (tag value)
  `(throw ,(unwalk-form tag) ,(unwalk-form value)))

;;;; EVAL-WHEN

(defunwalker-handler eval-when-form ()
  (error "Sorry, EVAL-WHEN not yet implemented."))

;;;; IF

(defunwalker-handler if-form (consequent then else)
  `(if ,(unwalk-form consequent) ,(unwalk-form then) ,(unwalk-form else)))

;;;; FLET/LABELS

(defunwalker-handler flet-form (binds body)
  (flet ((unwalk-flet (binds)
	   (mapcar #'(lambda (bind)
		       (cons (car bind)
			     (cdr (unwalk-form (cdr bind)))))
		   binds)))
    `(flet ,(unwalk-flet binds) ,@(unwalk-forms body))))

(defunwalker-handler labels-form (binds body)
  (flet ((unwalk-labels (binds)
	   (mapcar #'(lambda (bind)
		       (cons (car bind)
			     (cdr (unwalk-form (cdr bind)))))
		   binds)))
    `(labels ,(unwalk-labels binds) ,@(unwalk-forms body))))

;;;; LET/LET*

(defunwalker-handler let-form (binds body)
  (flet ((unwalk-let (binds)
	   (mapcar #'(lambda (bind)
		       (list (car bind)
			     (unwalk-form (cdr bind))))
		   binds)))
    `(let ,(unwalk-let binds) ,@(unwalk-forms body))))

(defunwalker-handler let*-form (binds body)
  (flet ((unwalk-let* (binds)
	   (mapcar #'(lambda (bind)
		       (list (car bind)
			     (unwalk-form (cdr bind))))
		   binds)))
    `(let* ,(unwalk-let* binds) ,@(unwalk-forms body))))

;;;; LOAD-TIME-VALUE

(defunwalker-handler load-time-value-form (value read-only-p)
  `(load-time-value ,(unwalk-form value) ,read-only-p))

;;;; LOCALLY

(defunwalker-handler locally-form (body)
  `(locally ,@(unwalk-forms body)))

;;;; MACROLET

(defunwalker-handler macrolet-form ()
  ;; We can't unwalk macrolet because, it contains closure objects.
  (error "Sorry, MACROLET not yet implemented."))

;;;; MULTIPLE-VALUE-CALL

(defunwalker-handler multiple-value-call-form (func arguments)
  `(multiple-value-call ,(unwalk-form func) ,@(unwalk-forms arguments)))

;;;; MULTIPLE-VALUE-PROG1

(defunwalker-handler multiple-value-prog1-form (first-form other-forms)
  `(multiple-value-prog1 ,(unwalk-form first-form) ,@(unwalk-forms other-forms)))

;;;; PROGN

(defunwalker-handler progn-form (body)
  `(progn ,@(unwalk-forms body)))

;;;; PROGV

(defunwalker-handler progv-form (body vars-form values-form)
  `(progv ,(unwalk-form vars-form) ,(unwalk-form values-form) ,@(unwalk-forms body)))

;;;; SETQ

(defunwalker-handler setq-form (var value)
  `(setq ,var ,(unwalk-form value)))

;;;; SYMBOL-MACROLET

(defunwalker-handler symbol-macrolet-form ()
  ;; We can't unwalk macrolet because, it modifies the body
  ;; expression, when its created.
  (error "Sorry, MACROLET not yet implemented."))

;;;; TAGBODY/GO

(defunwalker-handler tagbody-form (body)
  `(tagbody ,@(unwalk-forms body)))

(defunwalker-handler go-tag-form (name)
  name)

(defunwalker-handler go-form (name)
  `(go ,name))

;;;; THE

(defunwalker-handler the-form (type-form value)
  `(the ,type-form ,(unwalk-form value)))

;;;; UNWIND-PROTECT

(defunwalker-handler unwind-protect-form (protected-form cleanup-form)
  `(unwind-protect ,(unwalk-form protected-form) ,@(unwalk-forms cleanup-form)))

;; Copyright (c) 2006, Hoan Ton-That
;; All rights reserved. 
;; 
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;; 
;;  - Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 
;;  - Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;;  - Neither the name of Hoan Ton-That, nor the names of the
;;    contributors may be used to endorse or promote products derived
;;    from this software without specific prior written permission.
;; 
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.