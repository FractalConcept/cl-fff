;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          clsql-uffi.asd
;;;; Purpose:       ASDF definition file for CLSQL UFFI Helper package
;;;; Programmer:    Kevin M. Rosenberg
;;;; Date Started:  Aug 2002
;;;;
;;;; $Id: clsql-uffi.asd 959 2003-11-13 05:58:22Z kevin $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(in-package cl-user)

;; need to load uffi for below output-files method 
(eval-when (:compile-toplevel :load-toplevel :execute)
  #+common-lisp-controller (require 'uffi)
  #-common-lisp-controller (asdf:operate 'asdf:load-op 'uffi))

(defpackage clsql-uffi-system (:use #:asdf #:cl))
(in-package clsql-uffi-system)

(defvar *library-file-dir* (append (pathname-directory *load-truename*)
				   (list "uffi")))

(defclass clsql-uffi-source-file (c-source-file)
  ())


(defmethod output-files ((o compile-op) (c clsql-uffi-source-file))
  (let* ((library-file-type
	  (funcall (intern (symbol-name'#:default-foreign-library-type)
			   (symbol-name '#:uffi))))
	 (found
	  (some #'(lambda (dir)
		    (probe-file (make-pathname
				 :directory dir
				 :name (component-name c)
				 :type library-file-type)))
		'((:absolute "usr" "lib" "clsql")))))
    (list (if found
	      found
	      (make-pathname :name (component-name c)
			     :type library-file-type
			     :directory *library-file-dir*)))))

(defmethod perform ((o load-op) (c clsql-uffi-source-file))
  nil) ;;; library will be loaded by a loader file

(defmethod perform ((o compile-op) (c clsql-uffi-source-file))
  (unless (zerop (run-shell-command
		  "cd ~A; make"
		  (namestring (make-pathname :name nil
					     :type nil
					     :directory *library-file-dir*))))
    (error 'operation-error :component c :operation o)))

#+(or allegro lispworks cmu sbcl openmcl mcl scl)
(defsystem clsql-uffi
  :name "cl-sql-base"
  :author "Kevin M. Rosenberg <kmr@debian.org>"
  :maintainer "Kevin M. Rosenberg <kmr@debian.org>"
  :licence "Lessor Lisp General Public License"
  :description "Common UFFI Helper functions for Common Lisp SQL Interface Library"
  :long-description "cl-sql-uffi package provides common helper functions using the UFFI for the CLSQL package."

  :depends-on (:uffi :clsql-base)
  
  :components
  ((:module :uffi
	    :components
	    (;(:clsql-uffi-source-file "uffi")
	     (:file "clsql-uffi-package")
	     (:file "clsql-uffi-loader" :depends-on ("clsql-uffi-package" ))
	     (:file "clsql-uffi" :depends-on ("clsql-uffi-loader"))))))
