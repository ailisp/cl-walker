
(defvar *arnesi-indents*
  '((with-input-from-file 4 &rest 2)
    (with-output-to-file 4 &rest 2)
    (while 4 &rest 2)
    (until 4 &rest 2)
    (switch 4 &rest 2)
    (eswitch 4 &rest 2)
    (cswitch 4 &rest 2)
    (dolist* 4 &rest 2)
    (with-unique-names 4 &rest 2)
    (do-range 4 &rest 2)
    (dotree 4 &rest 2)
    (progr 4 &rest 2)
    (list-match-case 4 &rest 2)
    (with-call/cc &rest 2)
    (let/cc 4 &rest 2)))    

(defun install-arnesi-indents ()
  (interactive)
  (dolist (symbol *arnesi-indents*)
    (put (car symbol) 'common-lisp-indent-function (cdr symbol))))

(defun uninstall-arnesi-indents ()
  (interactive)
  (dolist (symbol *arnesi-indents*)
    (put symbol 'common-lisp-indent-function nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Copyright (c) 2002-2003, Edward Marco Baringer
;;;; All rights reserved. 
;;;; 
;;;; Redistribution and use in source and binary forms, with or without
;;;; modification, are permitted provided that the following conditions are
;;;; met:
;;;; 
;;;;  - Redistributions of source code must retain the above copyright
;;;;    notice, this list of conditions and the following disclaimer.
;;;; 
;;;;  - Redistributions in binary form must reproduce the above copyright
;;;;    notice, this list of conditions and the following disclaimer in the
;;;;    documentation and/or other materials provided with the distribution.
;;;;
;;;;  - Neither the name of Edward Marco Baringer, nor BESE, nor the names
;;;;    of its contributors may be used to endorse or promote products
;;;;    derived from this software without specific prior written permission.
;;;; 
;;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
;;;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;;;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;;;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;;;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;;;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;;;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
