;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          loop-extension.cl
;;;; Purpose:       Extensions to the Loop macro for CMUCL
;;;; Programmer:    Pierre R. Mai
;;;;
;;;; Copyright (c) 1999-2001 Pierre R. Mai
;;;;
;;;; $Id: loop-extension.lisp 936 2003-09-07 06:34:45Z kevin $
;;;;
;;;; The functions in this file were orignally distributed in the
;;;; MaiSQL package in the file sql/sql.cl
;;;; *************************************************************************

(in-package :cl-user)

;;;; MIT-LOOP extension

#+(or cmu scl)
(defun loop-record-iteration-path (variable data-type prep-phrases)
  (let ((in-phrase nil)
	(from-phrase nil))
    (loop for (prep . rest) in prep-phrases
	  do
	  (case prep
	    ((:in :of)
	     (when in-phrase
	       (ansi-loop::loop-error
		"Duplicate OF or IN iteration path: ~S." (cons prep rest)))
	     (setq in-phrase rest))
	    ((:from)
	     (when from-phrase
	       (ansi-loop::loop-error
		"Duplicate FROM iteration path: ~S." (cons prep rest)))
	     (setq from-phrase rest))
	    (t
	     (ansi-loop::loop-error
	      "Unknown preposition: ~S." prep))))
    (unless in-phrase
      (ansi-loop::loop-error "Missing OF or IN iteration path."))
    (unless from-phrase
      (setq from-phrase '(*default-database*)))
    (cond
      ((consp variable)
       (let ((query-var (ansi-loop::loop-gentemp 'loop-record-))
	     (db-var (ansi-loop::loop-gentemp 'loop-record-database-))
	     (result-set-var (ansi-loop::loop-gentemp
			      'loop-record-result-set-))
	     (step-var (ansi-loop::loop-gentemp 'loop-record-step-)))
	 (push `(when ,result-set-var
		 (database-dump-result-set ,result-set-var ,db-var))
	       ansi-loop::*loop-epilogue*)
	 `(((,variable nil ,data-type) (,query-var ,(first in-phrase))
	    (,db-var ,(first from-phrase))
	    (,result-set-var nil)
	    (,step-var nil))
	   ((multiple-value-bind (%rs %cols)
		(database-query-result-set ,query-var ,db-var)
	      (setq ,result-set-var %rs ,step-var (make-list %cols))))
	   ()
	   ()
	   (not (database-store-next-row ,result-set-var ,db-var ,step-var))
	   (,variable ,step-var)
	   (not ,result-set-var)
	   ()
	   (not (database-store-next-row ,result-set-var ,db-var ,step-var))
	   (,variable ,step-var))))
      (t
       (let ((query-var (ansi-loop::loop-gentemp 'loop-record-))
	     (db-var (ansi-loop::loop-gentemp 'loop-record-database-))
	     (result-set-var (ansi-loop::loop-gentemp
			      'loop-record-result-set-)))
	 (push `(when ,result-set-var
		 (database-dump-result-set ,result-set-var ,db-var))
	       ansi-loop::*loop-epilogue*)
	 `(((,variable nil ,data-type) (,query-var ,(first in-phrase))
	    (,db-var ,(first from-phrase))
	    (,result-set-var nil))
	   ((multiple-value-bind (%rs %cols)
		(database-query-result-set ,query-var ,db-var)
	      (setq ,result-set-var %rs ,variable (make-list %cols))))
	   ()
	   ()
	   (not (database-store-next-row ,result-set-var ,db-var ,variable))
	   ()
	   (not ,result-set-var)
	   ()
	   (not (database-store-next-row ,result-set-var ,db-var ,variable))
	   ()))))))

#+(or cmu scl)
(ansi-loop::add-loop-path '(record records tuple tuples)
			  'loop-record-iteration-path
			  ansi-loop::*loop-ansi-universe*
			  :preposition-groups '((:of :in) (:from))
			  :inclusive-permitted nil)
