;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          mysql-loader.sql
;;;; Purpose:       MySQL library loader using UFFI
;;;; Programmers:   Kevin M. Rosenberg
;;;; Date Started:  Feb 2002
;;;;
;;;; $Id: mysql-loader.lisp 978 2003-11-25 06:37:14Z kevin $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(in-package :mysql)

;;;; Modified by Kevin Rosenberg 
;;;;  - probe potential directories to find library
;;;;  - Changed from CMUCL functions to UFFI to
;;;;      -- prevent library from being loaded multiple times
;;;;      -- support Allegro CL and Lispworks

(defparameter *clsql-mysql-library-path* 
  (uffi:find-foreign-library
   "mysql"
   `(,(make-pathname :directory (pathname-directory *load-truename*))
     "/usr/lib/clsql/"
     "/sw/lib/clsql/"
     "/home/kevin/debian/src/clsql/db-mysql/")
   :drive-letters '("C")))

(defparameter *libz-library-path* 
  (uffi:find-foreign-library
   '("libz" "zlib")
   `(,(make-pathname :directory (pathname-directory *load-truename*))
      "/usr/lib/"
      "/sw/lib/"
      "/usr/local/lib/"
      "/home/kevin/debian/src/clsql/db-mysql/"
      "/mysql/lib/opt/")
   :drive-letters '("C")))
  
(defvar *mysql-library-candidate-names*
    '("libmysqlclient" "libmysql"))

(defparameter *mysql-library-candidate-directories*
    `(,(pathname-directory *load-pathname*)
      "/opt/mysql/lib/mysql/" "/usr/local/lib/" "/usr/lib/" "/usr/local/lib/mysql/" "/usr/lib/mysql/" "/mysql/lib/opt/" "/sw/lib/mysql/"))

(defvar *mysql-library-candidate-drive-letters* '("C" "D" "E"))

(defvar *mysql-supporting-libraries* '("c")
  "Used only by CMU. List of library flags needed to be passed to ld to
load the MySQL client library succesfully.  If this differs at your site,
set to the right path before compiling or loading the system.")

(defvar *mysql-library-loaded* nil
  "T if foreign library was able to be loaded successfully")

(defmethod clsql-base-sys:database-type-library-loaded ((database-type (eql :mysql)))
  *mysql-library-loaded*)
				      
(defmethod clsql-base-sys:database-type-load-foreign ((database-type (eql :mysql)))
  (let ((mysql-path
	 (uffi:find-foreign-library *mysql-library-candidate-names*
				    *mysql-library-candidate-directories*
				    :drive-letters
				    *mysql-library-candidate-drive-letters*)))
    (unless (probe-file mysql-path)
      (error "Can't find mysql client library to load"))
    (uffi:load-foreign-library *libz-library-path*) 
    (uffi:load-foreign-library mysql-path
			       :module "mysql" 
			       :supporting-libraries 
			       *mysql-supporting-libraries*)
    (uffi:load-foreign-library *clsql-mysql-library-path* 
			       :module "clsql-mysql" 
			       :supporting-libraries 
			       (append *mysql-supporting-libraries*)))
  (setq *mysql-library-loaded* t))


(clsql-base-sys:database-type-load-foreign :mysql)

