;; -*- lisp -*-

(in-package :it.bese.arnesi)

;;;; * A Trivial logging facility

;;;; A logger is a way to have the system generate a text message and
;;;; have that messaged saved somewhere for future review. Logging can
;;;; be used as a debugging mechinasm or for just reporting on the
;;;; status of a system.

;;;; Logs are sent to a particular log category, each log category
;;;; sends the messages it recieves to its handlers. A handler's job
;;;; is to take a message and write it somewhere. Log categories are
;;;; organized in a hierarchy and messages sent to a log cateogry will
;;;; also be sent to that category's ancestors.

;;;; Each log category has a log level which is used to determine
;;;; whether are particular message should be processed or
;;;; not. Categories inheirt their log level fro their ancestors. If a
;;;; category has multiple fathers its log level is the min of the
;;;; levels of its fathers.

;;;; ** Log Levels

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +dribble+ 0)
  (defconstant +debug+   1)
  (defconstant +info+    2)
  (defconstant +warn+    3)
  (defconstant +error+   4)
  (defconstant +fatal+   5)

  (deflookup-table logger))

;;;; ** Log Categories

(defclass log-category ()
  ((ancestors :initform '()     :accessor ancestors :initarg :ancestors)
   (childer   :initform '()     :Accessor childer   :initarg :childer)
   (appenders :initform '()     :accessor appenders :initarg :appenders)
   (level     :initform +debug+ :initarg :level :accessor level)
   (name      :initarg :name :accessor name)))

(defmethod shared-initialize :after ((l log-category) slot-names
                                     &key ancestors &allow-other-keys)
  (declare (ignore slot-names))
  (dolist (anc ancestors)
    (pushnew l (childer anc) :test (lambda (a b)
				     (eql (name a) (name b))))))

(defmethod enabled-p ((cat log-category) level)
  (>= level (log.level cat)))

(defmethod log.level ((cat log-category))
  (with-slots (level) cat
    (or level
        (if (ancestors cat)
            (loop for ancestor in (ancestors cat)
                  minimize (log.level ancestor))
            (error "Can't determine level for ~S" cat)))))

(defmethod (setf log.level) (new-level (cat log-category)
                             &optional (recursive t))
  "Change the log level of CAT to NEW-LEVEL. If RECUSIVE is T the
  setting is also applied to the sub categories of CAT."
  (setf (slot-value cat 'level) new-level)
  (when recursive
    (dolist (child (childer cat))
      (setf (log.level child) new-level))))

;;;; ** Handling Messages

(defgeneric handle (category message level))

(defmethod handle ((cat log-category) message level)
  (if (appenders cat)
      ;; if we have any appenders send them the message
      (dolist (appender (appenders cat))
	(append-message cat appender message level))
      ;; send the message to our ancestors
      (dolist (ancestor (ancestors cat))
	(handle ancestor message level))))

(defgeneric append-message (category log-appender message level))

;;;; *** Stream log appender

(defclass stream-log-appender ()
  ((stream :initarg :stream :accessor log-stream))
  (:documentation "Human readable to the console logger."))

(defmethod append-message ((category log-category) (s stream-log-appender)
                           message level)
  (multiple-value-bind (second minute hour date month year)
      (decode-universal-time (get-universal-time))
    (restart-case
        (progn
          (format (log-stream s)
                  "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D.~2,'0D ~S ~S: "
                  year month date hour minute second
                  level (name category))
          (format (log-stream s) "~A~%" message))
      (use-*debug-io* ()
        :report "Use the current value of *debug-io*"
        (setf (log-stream s) *debug-io*)
        (append-message category s message level))
      (use-*standard-output* ()
        :report "Use the current value of *standard-output*"
        (setf (log-stream s) *standard-output*)
        (append-message category s message level))
      (silence-logger ()
        :report "Ignore all future messages to this logger."
        (setf (log-stream s) (make-broadcast-stream))))))

(defun make-stream-log-appender (&optional (stream *debug-io*))
  (make-instance 'stream-log-appender :stream stream))

(defclass file-log-appender (stream-log-appender)
  ((log-file :initarg :log-file :accessor log-file))
  (:documentation "Logs to a file. the output of the file logger
  is not meant to be read directly by a human."))

(defmethod append-message ((category log-category) (appender file-log-appender)
                           message level)
  (with-output-to-file (log-file (log-file appender)
				 :if-exists :append
				 :if-does-not-exist :create)
    (let ((*package* (find-package :it.bese.arnesi)))
      (format log-file "(~S ~D ~S ~S)~%" level (get-universal-time) (name category) message))))

(defun make-file-log-appender (file-name)
  (make-instance 'file-log-appender :log-file file-name))

;;;; ** Creating Loggers

(defmacro deflogger (name ancestors &key level appender appenders documentation)
  (declare (ignore documentation))
  (when appender
    (setf appenders (append appenders (list appender))))
  (let ((ancestors (mapcar (lambda (ancestor-name)
			     `(or (get-logger ',ancestor-name)
				  (error "Attempt to define a sub logger of the undefined logger ~S."
					 ',ancestor-name)))
			   ancestors)))
    (flet ((make-log-helper (suffix level)
	     `(defmacro ,(intern (strcat name "." suffix)) (message-control &rest message-args)
		`(when (enabled-p (get-logger ',',name) ,',level)
		   ,(if message-args
			`(handle (get-logger ',',name) (format nil ,message-control ,@message-args) ',',level)
			`(handle (get-logger ',',name) ,message-control ',',level))))))
      `(progn
	 (setf (get-logger ',name) (make-instance 'log-category
						  :name ',name
						  :level ,level
						  :appenders (list ,@appenders)
						  :ancestors (list ,@ancestors)))
	 ,(make-log-helper '#:dribble '+dribble+)
	 ,(make-log-helper '#:info '+info+)
	 ,(make-log-helper '#:warn '+warn+)
	 ,(make-log-helper '#:error '+error+)
	 ,(make-log-helper '#:fatal '+fatal+)))))

;; Copyright (c) 2002-2005, Edward Marco Baringer
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
;;  - Neither the name of Edward Marco Baringer, nor BESE, nor the names
;;    of its contributors may be used to endorse or promote products
;;    derived from this software without specific prior written permission.
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