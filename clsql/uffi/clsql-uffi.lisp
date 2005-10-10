;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          clsql-uffi.cl
;;;; Purpose:       Common functions for interfaces using UFFI
;;;; Programmers:   Kevin M. Rosenberg
;;;; Date Started:  Mar 2002
;;;;
;;;; $Id: clsql-uffi.lisp 980 2003-11-25 13:30:49Z kevin $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(in-package #:clsql-uffi)


(defun canonicalize-type-list (types auto-list)
  "Ensure a field type list meets expectations"
  (declaim (optimize (speed 3) (safety 0)))
  (do ((i 0 (1+ i))
       (new-types '())
       (length-types (length types))
       (length-auto-list (length auto-list)))
      ((= i length-auto-list)
       (nreverse new-types))
    (declaim (fixnum length-types length-auto-list i))
    (if (>= i length-types)
	(push t new-types) ;; types is shorted than num-fields
	(push
	 (case (nth i types)
	   (:int
	    (case (nth i auto-list)
	      (:int32
	       :int32)
	      (:int64
	       :int64)
	      (t
	       t)))
	   (:double
	    (case (nth i auto-list)
	      (:double
	       :double)
	      (t
	       t)))
	   (:int32
	    (if (eq :int32 (nth i auto-list))
		:int32
		t))
	   (:int64
	    (if (eq :int64 (nth i auto-list))
		:int64
		t))
	   (t
	    t))
	 new-types))))

(uffi:def-function "atoi"
    ((str (* :unsigned-char)))
  :returning :int)

(uffi:def-function "atol"
    ((str (* :unsigned-char)))
  :returning :long)

(uffi:def-function "atof"
    ((str (* :unsigned-char)))
  :returning :double)

(uffi:def-function "atol64"
    ((str (* :unsigned-char))
     (high32 (* :int)))
  :returning :unsigned-int)

(uffi:def-constant +2^32+ 4294967296)
(uffi:def-constant +2^32-1+ (1- +2^32+))

(defmacro make-64-bit-integer (high32 low32)
  `(+ ,low32 (ash ,high32 32)))

(defmacro split-64-bit-integer (int64)
  `(values (ash ,int64 -32) (logand ,int64 +2^32-1+)))

(uffi:def-type char-ptr-def (* :unsigned-char))

(defun convert-raw-field (char-ptr types index &optional length)
  (declare (optimize (speed 3) (safety 0) (space 0))
 	   (type char-ptr-def char-ptr))
  (let ((type (if (listp types)
		  (nth index types)
		  types)))
    (cond
      ((uffi:null-pointer-p char-ptr)
       nil)
      (t
       (case type
	 (:double
	  (atof char-ptr))
	 ((or :int32 :int)
	  (atoi char-ptr))
	 (:int64
	  (uffi:with-foreign-object (high32-ptr :int)
	    (let ((low32 (atol64 char-ptr high32-ptr))
		  (high32 (uffi:deref-pointer high32-ptr :int)))
	      (if (zerop high32)
		  low32
		  (make-64-bit-integer high32 low32)))))
	 (t
          (if length
	      (uffi:convert-from-foreign-string char-ptr :locale :none
                                                :null-terminated-p nil
                                                :length length)
            (uffi:convert-from-foreign-string char-ptr :locale :none))))))))

