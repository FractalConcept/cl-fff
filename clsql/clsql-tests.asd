;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          clsql-tests.asd
;;;; Purpose:       ASDF system definitionf for clsql testing package
;;;; Author:        Kevin M. Rosenberg
;;;; Date Started:  Apr 2003
;;;;
;;;; $Id: clsql-tests.asd 959 2003-11-13 05:58:22Z kevin $
;;;; *************************************************************************

(in-package #:cl-user)
(defpackage #:clsql-tests-system (:use #:asdf #:cl))
(in-package #:clsql-tests-system)

(defsystem clsql-tests
  :name "clsql-tests"
  :author "Kevin Rosenberg <kevin@rosenberg.net>"
  :maintainer "Kevin M. Rosenberg <kmr@debian.org>"
  :licence "Lessor Lisp General Public License"
  :description "Testing suite for CLSQL"

  :depends-on (:clsql :clsql-mysql :clsql-postgresql :clsql-postgresql-socket
		      :ptester
		      #+(and allegro (not allegro-cl-trial)) :clsql-aodbc)
  :components
  ((:module tests
	    :components
	    ((:file "package")
;;	     (:file "tables" :depends-on ("package")))
	     (:file "tests" :depends-on ("package")))
	    )))

(defmethod perform ((o test-op) (c (eql (find-system 'clsql-tests))))
  (unless (funcall (intern (symbol-name '#:run-tests)
			   (find-package '#:clsql-tests)))
    (error "test-op failed")))

