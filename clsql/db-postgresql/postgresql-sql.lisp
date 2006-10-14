;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          postgresql-sql.lisp
;;;; Purpose:       High-level PostgreSQL interface using UFFI
;;;; Programmers:   Kevin M. Rosenberg based on
;;;;                Original code by Pierre R. Mai 
;;;; Date Started:  Feb 2002
;;;;
;;;; $Id: postgresql-sql.lisp 936 2003-09-07 06:34:45Z kevin $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;; and Copyright (c) 1999-2001 by Pierre R. Mai
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(in-package #:cl-user)

(defpackage #:clsql-postgresql
    (:use #:common-lisp #:clsql-base-sys #+lispworks5 #:db-postgresql #-lispworks5 #:postgresql #:clsql-uffi)
    (:export #:postgresql-database)
    (:documentation "This is the CLSQL interface to PostgreSQL."))

(in-package #:clsql-postgresql)

;;; Field conversion functions

(defun make-type-list-for-auto (num-fields res-ptr)
  (let ((new-types '()))
    (dotimes (i num-fields)
      (declare (fixnum i))
      (let* ((type (PQftype res-ptr i)))
	(push
	 (case type
	   ((#.pgsql-ftype#bytea
	     #.pgsql-ftype#int2
	     #.pgsql-ftype#int4)
	    :int32)
	   (#.pgsql-ftype#int8
	    :int64)
	   ((#.pgsql-ftype#float4
	     #.pgsql-ftype#float8)
	    :double)
	   (otherwise
	    t))
	 new-types)))
      (nreverse new-types)))

(defun canonicalize-types (types num-fields res-ptr)
  (if (null types)
      nil
      (let ((auto-list (make-type-list-for-auto num-fields res-ptr)))
	(cond
	  ((listp types)
	   (canonicalize-type-list types auto-list))
	  ((eq types :auto)
	   auto-list)
	  (t
	   nil)))))

(defun tidy-error-message (message)
  (unless (stringp message)
    (setq message (uffi:convert-from-foreign-string message)))
  (let ((message (string-right-trim '(#\Return #\Newline) message)))
    (cond
      ((< (length message) (length "ERROR:"))
       message)
      ((string= message "ERROR:" :end1 6)
       (string-left-trim '(#\Space) (subseq message 6)))
      (t
       message))))

(defmethod database-initialize-database-type ((database-type
					       (eql :postgresql)))
  t)

(uffi:def-type pgsql-conn-def pgsql-conn)
(uffi:def-type pgsql-result-def pgsql-result)


(defclass postgresql-database (database)
  ((conn-ptr :accessor database-conn-ptr :initarg :conn-ptr
	     :type pgsql-conn-def)))

(defmethod database-type ((database postgresql-database))
  :postgresql)

(defmethod database-name-from-spec (connection-spec (database-type
						     (eql :postgresql)))
  (check-connection-spec connection-spec database-type
			 (host db user password &optional port options tty))
  (destructuring-bind (host db user password &optional port options tty)
      connection-spec
    (declare (ignore password options tty))
    (concatenate 'string 
      (etypecase host
	(pathname (namestring host))
	(string host))
      (when port 
	(concatenate 'string
		     ":"
		     (etypecase port
		       (integer (write-to-string port))
		       (string port))))
      "/" db "/" user)))


(defmethod database-connect (connection-spec (database-type (eql :postgresql)))
  (check-connection-spec connection-spec database-type
			 (host db user password &optional port options tty))
  (destructuring-bind (host db user password &optional port options tty)
      connection-spec
    (uffi:with-cstrings ((host-native host)
			 (user-native user)
			 (password-native password)
			 (db-native db)
			 (port-native port)
			 (options-native options)
			 (tty-native tty))
      (let ((connection (PQsetdbLogin host-native port-native
				      options-native tty-native
				      db-native user-native
				      password-native)))
	(declare (type pgsql-conn-def connection))
	(when (not (eq (PQstatus connection) 
		       pgsql-conn-status-type#connection-ok))
	  (error 'clsql-connect-error
		 :database-type database-type
		 :connection-spec connection-spec
		 :errno (PQstatus connection)
		 :error (tidy-error-message 
			 (PQerrorMessage connection))))
	(make-instance 'postgresql-database
		       :name (database-name-from-spec connection-spec
						      database-type)
		       :connection-spec connection-spec
		       :conn-ptr connection)))))


(defmethod database-disconnect ((database postgresql-database))
  (PQfinish (database-conn-ptr database))
  (setf (database-conn-ptr database) nil)
  t)

(defmethod database-query (query-expression (database postgresql-database) types)
  (let ((conn-ptr (database-conn-ptr database)))
    (declare (type pgsql-conn-def conn-ptr))
    (uffi:with-cstring (query-native query-expression)
      (let ((result (PQexec conn-ptr query-native)))
        (when (uffi:null-pointer-p result)
          (error 'clsql-sql-error
                 :database database
                 :expression query-expression
                 :errno nil
                 :error (tidy-error-message (PQerrorMessage conn-ptr))))
        (unwind-protect
            (case (PQresultStatus result)
              (#.pgsql-exec-status-type#empty-query
               nil)
              (#.pgsql-exec-status-type#tuples-ok
	       (let ((num-fields (PQnfields result)))
		 (setq types
		   (canonicalize-types types num-fields
					     result))
		 (loop for tuple-index from 0 below (PQntuples result)
		       collect
		       (loop for i from 0 below num-fields
			     collect
			     (if (zerop (PQgetisnull result tuple-index i))
				 (convert-raw-field
				  (PQgetvalue result tuple-index i)
				  types i)
				 nil)))))
              (t
               (error 'clsql-sql-error
                      :database database
                      :expression query-expression
                      :errno (PQresultStatus result)
                      :error (tidy-error-message
                              (PQresultErrorMessage result)))))
          (PQclear result))))))

(defmethod database-execute-command (sql-expression
                                     (database postgresql-database))
  (let ((conn-ptr (database-conn-ptr database)))
    (declare (type pgsql-conn-def conn-ptr))
    (uffi:with-cstring (sql-native sql-expression)
      (let ((result (PQexec conn-ptr sql-native)))
        (when (uffi:null-pointer-p result)
          (error 'clsql-sql-error
                 :database database
                 :expression sql-expression
                 :errno nil
                 :error (tidy-error-message (PQerrorMessage conn-ptr))))
        (unwind-protect
            (case (PQresultStatus result)
              (#.pgsql-exec-status-type#command-ok
               t)
              ((#.pgsql-exec-status-type#empty-query
                #.pgsql-exec-status-type#tuples-ok)
               (warn "Strange result...")
               t)
              (t
               (error 'clsql-sql-error
                      :database database
                      :expression sql-expression
                      :errno (PQresultStatus result)
                      :error (tidy-error-message
                              (PQresultErrorMessage result)))))
          (PQclear result))))))

(defstruct postgresql-result-set
  (res-ptr (uffi:make-null-pointer 'pgsql-result) 
	   :type pgsql-result-def)
  (types nil) 
  (num-tuples 0 :type integer)
  (num-fields 0 :type integer)
  (tuple-index 0 :type integer))

(defmethod database-query-result-set (query-expression (database postgresql-database) 
                                      &key full-set types)
  (let ((conn-ptr (database-conn-ptr database)))
    (declare (type pgsql-conn-def conn-ptr))
    (uffi:with-cstring (query-native query-expression)
      (let ((result (PQexec conn-ptr query-native)))
        (when (uffi:null-pointer-p result)
          (error 'clsql-sql-error
                 :database database
                 :expression query-expression
                 :errno nil
                 :error (tidy-error-message (PQerrorMessage conn-ptr))))
        (case (PQresultStatus result)
          ((#.pgsql-exec-status-type#empty-query
            #.pgsql-exec-status-type#tuples-ok)
	   (let ((result-set (make-postgresql-result-set
                        :res-ptr result
                        :num-fields (PQnfields result)
                        :num-tuples (PQntuples result)
			:types (canonicalize-types 
				      types
				      (PQnfields result)
				      result))))
	     (if full-set
		 (values result-set
			 (PQnfields result)
			 (PQntuples result))
		 (values result-set
			 (PQnfields result)))))
	  (t
	   (unwind-protect
               (error 'clsql-sql-error
                      :database database
                      :expression query-expression
                      :errno (PQresultStatus result)
                      :error (tidy-error-message
                              (PQresultErrorMessage result)))
             (PQclear result))))))))
  
(defmethod database-dump-result-set (result-set (database postgresql-database))
  (let ((res-ptr (postgresql-result-set-res-ptr result-set))) 
    (declare (type pgsql-result-def res-ptr))
    (PQclear res-ptr)
    t))

(defmethod database-store-next-row (result-set (database postgresql-database) 
                                    list)
  (let ((result (postgresql-result-set-res-ptr result-set))
	(types (postgresql-result-set-types result-set)))
    (declare (type pgsql-result-def result))
    (if (>= (postgresql-result-set-tuple-index result-set)
	    (postgresql-result-set-num-tuples result-set))
	nil
      (loop with tuple-index = (postgresql-result-set-tuple-index result-set)
          for i from 0 below (postgresql-result-set-num-fields result-set)
          for rest on list
          do
            (setf (car rest)
              (if (zerop (PQgetisnull result tuple-index i))
                  (convert-raw-field
                   (PQgetvalue result tuple-index i)
		   types i)
                nil))
          finally
            (incf (postgresql-result-set-tuple-index result-set))
            (return list)))))

;;; Large objects support (Marc B)
(defconstant +INV_ARCHIVE+ 65536)         ; fe-lobj.c
(defconstant +INV_WRITE+   131072)
(defconstant +INV_READ+    262144)

(defmethod database-create-large-object ((database postgresql-database))
  (lo-create (database-conn-ptr database)
	     (logior +INV_WRITE+ +INV_READ+)))


#+mb-original
(defmethod database-write-large-object (object-id (data string) (database postgresql-database))
  (let ((ptr (database-conn-ptr database))
	(length (length data))
	(result nil)
	(fd nil))
    (with-transaction (:database database)
       (unwind-protect
	  (progn 
	    (setf fd (lo-open ptr object-id +INV_WRITE+))
	    (when (>= fd 0)
	      (when (= (lo-write ptr fd data length) length)
		(setf result t))))
	 (progn
	   (when (and fd (>= fd 0))
	     (lo-close ptr fd))
	   )))
    result))

(defmethod database-write-large-object (object-id (data string) (database postgresql-database))
  (let ((ptr (database-conn-ptr database))
	(length (length data))
	(result nil)
	(fd nil))
    (database-execute-command "begin" database)
    (unwind-protect
	(progn 
	  (setf fd (lo-open ptr object-id +INV_WRITE+))
	  (when (>= fd 0)
	    (when (= (lo-write ptr fd data length) length)
	      (setf result t))))
      (progn
	(when (and fd (>= fd 0))
	  (lo-close ptr fd))
	(database-execute-command (if result "commit" "rollback") database)))
    result))

;; (MB) the begin/commit/rollback stuff will be removed when with-transaction wil be implemented
;; (KMR) Can't use with-transaction since that function is in high-level code
(defmethod database-read-large-object (object-id (database postgresql-database))
  (let ((ptr (database-conn-ptr database))
	(buffer nil)
	(result nil)
	(length 0)
	(fd nil))
    (unwind-protect
       (progn
	 (database-execute-command "begin" database)
	 (setf fd (lo-open ptr object-id +INV_READ+))
	 (when (>= fd 0)
	   (setf length (lo-lseek ptr fd 0 2))
	   (lo-lseek ptr fd 0 0)
	   (when (> length 0)
	     (setf buffer (uffi:allocate-foreign-string 
			   length :unsigned t))
	     (when (= (lo-read ptr fd buffer length) length)
	       (setf result (uffi:convert-from-foreign-string
			     buffer :length length :null-terminated-p nil))))))
      (progn
	(when buffer (uffi:free-foreign-object buffer))
	(when (and fd (>= fd 0)) (lo-close ptr fd))
	(database-execute-command (if result "commit" "rollback") database)))
    result))

(defmethod database-delete-large-object (object-id (database postgresql-database))
  (lo-unlink (database-conn-ptr database) object-id))

(when (clsql-base-sys:database-type-library-loaded :postgresql)
  (clsql-base-sys:initialize-database-type :database-type :postgresql))
