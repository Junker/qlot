(defpackage #:qlot/utils
  (:use #:cl)
  (:export #:with-in-directory
           #:make-keyword
           #:split-with
           #:generate-random-string
           #:with-package-functions
           #:pathname-in-directory-p
           #:merge-hash-tables
           #:octets-stream-to-string))
(in-package #:qlot/utils)

(defmacro with-in-directory (dir &body body)
  (let ((cwd (gensym "CWD")))
    `(let ((,cwd (uiop:getcwd)))
       (uiop:chdir ,dir)
       (unwind-protect
            (progn ,@body)
         (uiop:chdir ,cwd)))))

(defun make-keyword (text)
  "This function differ from alexandria:make-keyword
   because it upcases text before making it a keyword."
  (intern (string-upcase text) :keyword))

(defun split-with (delimiter value &key limit)
  (check-type delimiter character)
  (check-type value string)
  (check-type limit (or null (integer 1)))
  (let ((results '())
        (pos 0)
        (count 0))
    (block nil
      (flet ((keep (i)
               (unless (= pos i)
                 (push (subseq value pos i) results)
                 (incf count))))
        (do ((i 0 (1+ i)))
            ((= i (length value))
             (keep i))
          (when (and limit
                     (= (1+ count) limit))
            (push (subseq value i (length value)) results)
            (return))
          (when (char= (aref value i) delimiter)
            (keep i)
            (setf pos (1+ i))))))
    (nreverse results)))

(defun generate-random-string ()
  (let ((*random-state* (make-random-state t)))
    (format nil "~36R" (random (expt 36 #-gcl 8 #+gcl 5)))))

(defmacro with-package-functions (package-designator functions &body body)
  (let ((args (gensym "ARGS")))
    `(flet (,@(loop for fn in functions
                    collect `(,fn (&rest ,args)
                                  (apply
                                   ,(if (and (listp fn) (eq (car fn) 'setf))
                                        `(eval `(function (setf ,(intern ,(string (cadr fn)) ',package-designator))))
                                        `(symbol-function (intern ,(string fn) ',package-designator)))
                                   ,args))))
       ,@body)))

(defun pathname-in-directory-p (path directory)
  (let ((directory (pathname-directory directory))
        (path (pathname-directory path)))
    (loop for dir1 = (pop directory)
          for dir2 = (pop path)
          if (null dir1)
            do (return t)
          else if (null dir2)
            do (return nil)
          else if (string/= dir1 dir2)
            do (return nil)
          finally
             (return t))))

(defun merge-hash-tables (from-table to-table)
  "Add all entries from FROM-TABLE to TO-TABLE, overwriting existing entries
with the same key."
  (flet ((add-to-original (value key)
           (setf (gethash value to-table) key)))
    (maphash #'add-to-original from-table)))

(defun octets-stream-to-string (stream)
  (let ((buffer (make-array 1024 :element-type '(unsigned-byte 8))))
    (with-output-to-string (s)
      (loop for read-bytes = (read-sequence buffer stream)
            do (write-string (map 'string #'code-char buffer) s)
            while (= read-bytes 1024)))))
