;;; calc-tests.el --- tests for calc                 -*- lexical-binding: t; -*-

;; Copyright (C) 2014-2020 Free Software Foundation, Inc.

;; Author: Leo Liu <sdl.web@gmail.com>
;; Keywords: maint

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'calc)
(require 'calc-ext)
(require 'calc-units)
(require 'calc-forms)

;; XXX The order in which calc libraries (in particular calc-units)
;; are loaded influences whether a calc integer in an expression
;; involving units is represented as a lisp integer or a calc float,
;; see bug#19582.  Until this will be fixed the following function can
;; be used to compare such calc expressions.
(defun calc-tests-equal (a b)
  "Like `equal' but allow for different representations of numbers.
For example: (calc-tests-equal 10 '(float 1 1)) => t.
A and B should be calc expressions."
  (cond ((math-numberp a)
	 (and (math-numberp b)
	      (math-equal a b)))
	((atom a)
	 (equal a b))
	((consp b)
	 ;; Can't be dotted or circular.
	 (and (= (length a) (length b))
	      (equal (car a) (car b))
	      (cl-every #'calc-tests-equal (cdr a) (cdr b))))))

(defun calc-tests-simple (fun string &rest args)
  "Push STRING on the calc stack, then call FUN and return the new top.
The result is a calc (i.e., lisp) expression, not its string representation.
Also pop the entire stack afterwards.
An existing calc stack is reused, otherwise a new one is created."
  (calc-eval string 'push)
  (prog1
      (ignore-errors
	(apply fun args)
	(calc-top-n 1))
    (calc-pop 0)))

(ert-deftest calc-remove-units ()
  (should (calc-tests-equal (calc-tests-simple #'calc-remove-units "-1 m") -1)))

(ert-deftest calc-extract-units ()
  (should (calc-tests-equal (calc-tests-simple #'calc-extract-units "-1 m")
			    '(var m var-m)))
  (should (calc-tests-equal (calc-tests-simple #'calc-extract-units "-1 m*cm")
			    '(* (float 1 -2) (^ (var m var-m) 2)))))

(ert-deftest calc-convert-units ()
  ;; Used to ask for `(The expression is unitless when simplified) Old Units: '.
  (should (calc-tests-equal (calc-tests-simple #'calc-convert-units "-1 m" nil "cm")
			    '(* -100 (var cm var-cm))))
  ;; Gave wrong result.
  (should (calc-tests-equal (calc-tests-simple #'calc-convert-units "-1 m"
					       (math-read-expr "1m") "cm")
			    '(* -100 (var cm var-cm)))))

(ert-deftest calc-imaginary-i ()
  "Test `math-imaginary-i' for non-special-const values."
  (let ((var-i (calcFunc-polar (calcFunc-sqrt -1))))
    (should (math-imaginary-i)))
  (let ((var-i (calcFunc-sqrt -1)))
    (should (math-imaginary-i))))

(ert-deftest calc-bug-23889 ()
  "Test for https://debbugs.gnu.org/23889 and 25652."
  (skip-unless t) ;; (>= math-bignum-digit-length 9))
  (dolist (mode '(deg rad))
    (let ((calc-angle-mode mode))
      ;; If user inputs angle units, then should ignore `calc-angle-mode'.
      (should (string= "5253"
                       (substring
                        (number-to-string
                         (nth 1
                              (math-simplify-units
                               '(calcFunc-cos (* 45 (var rad var-rad))))))
                        0 4)))
      (should (string= "7071"
                       (substring
                        (number-to-string
                         (nth 1
                              (math-simplify-units
                               '(calcFunc-cos (* 45 (var deg var-deg))))))
                        0 4)))
      (should (string= "8939"
                       (substring
                        (number-to-string
                         (nth 1
                              (math-simplify-units
                               '(+ (calcFunc-sin (* 90 (var rad var-rad)))
                                   (calcFunc-cos (* 90 (var deg var-deg)))))))
                        0 4)))
      (should (string= "5519"
                       (substring
                        (number-to-string
                         (nth 1
                              (math-simplify-units
                               '(+ (calcFunc-sin (* 90 (var deg var-deg)))
                                   (calcFunc-cos (* 90 (var rad var-rad)))))))
                        0 4)))
      ;; If user doesn't input units, then must use `calc-angle-mode'.
      (should (string= (if (eq calc-angle-mode 'deg)
                           "9998"
                         "5403")
                       (substring
                        (number-to-string
                         (nth 1 (calcFunc-cos 1)))
                        0 4))))))

(ert-deftest calc-trig ()
  "Trigonometric simplification; bug#33052."
  (let ((calc-angle-mode 'rad))
    (let ((calc-symbolic-mode t))
      (should (equal (math-simplify '(calcFunc-sin (/ (var pi var-pi) 4)))
                     '(/ (calcFunc-sqrt 2) 2)))
      (should (equal (math-simplify '(calcFunc-cos (/ (var pi var-pi) 4)))
                     '(/ (calcFunc-sqrt 2) 2)))
      (should (equal (math-simplify '(calcFunc-sec (/ (var pi var-pi) 4)))
                     '(calcFunc-sqrt 2)))
      (should (equal (math-simplify '(calcFunc-csc (/ (var pi var-pi) 4)))
                     '(calcFunc-sqrt 2)))
      (should (equal (math-simplify '(calcFunc-tan (/ (var pi var-pi) 3)))
                     '(calcFunc-sqrt 3)))
      (should (equal (math-simplify '(calcFunc-cot (/ (var pi var-pi) 3)))
                     '(/ (calcFunc-sqrt 3) 3))))
    (let ((calc-symbolic-mode nil))
      (should (equal (math-simplify '(calcFunc-sin (/ (var pi var-pi) 4)))
                     '(calcFunc-sin (/ (var pi var-pi) 4))))
      (should (equal (math-simplify '(calcFunc-cos (/ (var pi var-pi) 4)))
                     '(calcFunc-cos (/ (var pi var-pi) 4))))
      (should (equal (math-simplify '(calcFunc-sec (/ (var pi var-pi) 4)))
                     '(calcFunc-sec (/ (var pi var-pi) 4))))
      (should (equal (math-simplify '(calcFunc-csc (/ (var pi var-pi) 4)))
                     '(calcFunc-csc (/ (var pi var-pi) 4))))
      (should (equal (math-simplify '(calcFunc-tan (/ (var pi var-pi) 3)))
                     '(calcFunc-tan (/ (var pi var-pi) 3))))
      (should (equal (math-simplify '(calcFunc-cot (/ (var pi var-pi) 3)))
                     '(calcFunc-cot (/ (var pi var-pi) 3)))))))

(ert-deftest calc-format-radix ()
  "Test integer formatting (bug#36689)."
  (let ((calc-group-digits nil))
    (let ((calc-number-radix 10))
      (should (equal (math-format-number 12345678901) "12345678901")))
    (let ((calc-number-radix 2))
      (should (equal (math-format-number 12345) "2#11000000111001")))
    (let ((calc-number-radix 8))
      (should (equal (math-format-number 12345678901) "8#133767016065")))
    (let ((calc-number-radix 16))
      (should (equal (math-format-number 12345678901) "16#2DFDC1C35")))
    (let ((calc-number-radix 36))
      (should (equal (math-format-number 12345678901) "36#5O6AQT1"))))
  (let ((calc-group-digits t))
    (let ((calc-number-radix 10))
      (should (equal (math-format-number 12345678901) "12,345,678,901")))
    (let ((calc-number-radix 2))
      (should (equal (math-format-number 12345) "2#11,0000,0011,1001")))
    (let ((calc-number-radix 8))
      (should (equal (math-format-number 12345678901) "8#133,767,016,065")))
    (let ((calc-number-radix 16))
      (should (equal (math-format-number 12345678901) "16#2,DFDC,1C35")))
    (let ((calc-number-radix 36))
      (should (equal (math-format-number 12345678901) "36#5,O6A,QT1")))))

(ert-deftest calc-calendar ()
  "Test calendar conversions (bug#36822)."
  (should (equal (calcFunc-julian (math-parse-date "2019-07-27")) 2458692))
  (should (equal (math-parse-date "2019-07-27") '(date 737267)))
  (should (equal (calcFunc-julian '(date 0)) 1721425))
  (should (equal (math-date-to-gregorian-dt 1) '(1 1 1)))
  (should (equal (math-date-to-gregorian-dt 0) '(-1 12 31)))
  (should (equal (math-date-to-gregorian-dt -1721425) '(-4714 11 24)))
  (should (equal (math-absolute-from-gregorian-dt 2019 7 27) 737267))
  (should (equal (math-absolute-from-gregorian-dt 1 1 1) 1))
  (should (equal (math-absolute-from-gregorian-dt -1 12 31) 0))
  (should (equal (math-absolute-from-gregorian-dt -99 12 31) -35795))
  (should (equal (math-absolute-from-gregorian-dt -4714 11 24) -1721425))
  (should (equal (calcFunc-julian '(date -1721425)) 0))
  (should (equal (math-date-to-julian-dt 1) '(1 1 3)))
  (should (equal (math-date-to-julian-dt -1721425) '(-4713 1 1)))
  (should (equal (math-absolute-from-julian-dt 2019 1 1) 737073))
  (should (equal (math-absolute-from-julian-dt 1 1 3) 1))
  (should (equal (math-absolute-from-julian-dt -101 1 1) -36892))
  (should (equal (math-absolute-from-julian-dt -101 3 1) -36832))
  (should (equal (math-absolute-from-julian-dt -4713 1 1) -1721425)))

(ert-deftest calc-solve-linear-system ()
  "Test linear system solving (bug#35374)."
  ;;   x + y =   3
  ;;  2x - 3y = -4
  ;; with the unique solution x=1, y=2
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 3)
              (calcFunc-eq (- (* 2 (var x var-x)) (* 3 (var y var-y))) -4))
            '(vec (var x var-x) (var y var-y)))
           '(vec (calcFunc-eq (var x var-x) 1)
                 (calcFunc-eq (var y var-y) 2))))

  ;;  x + y = 1
  ;;  x + y = 2
  ;; has no solution
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 1)
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 2))
            '(vec (var x var-x) (var y var-y)))
           '(calcFunc-solve
             (vec
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 1)
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 2))
             (vec (var x var-x) (var y var-y)))))
  ;;   x - y = 1
  ;;   x + y = 1
  ;; with the unique solution x=1, y=0
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (- (var x var-x) (var y var-y)) 1)
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 1))
            '(vec (var x var-x) (var y var-y)))
           '(vec (calcFunc-eq (var x var-x) 1)
                 (calcFunc-eq (var y var-y) 0))))
  ;;  2x - 3y +  z =  5
  ;;   x +  y - 2z =  0
  ;;  -x + 2y + 3z = -3
  ;; with the unique solution x=1, y=-1, z=0
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq
               (+ (- (* 2 (var x var-x)) (* 3 (var y var-y))) (var z var-z))
               5)
              (calcFunc-eq
               (- (+ (var x var-x) (var y var-y)) (* 2 (var z var-z)))
               0)
              (calcFunc-eq
               (+ (- (* 2 (var y var-y)) (var x var-x)) (* 3 (var z var-z)))
               -3))
            '(vec (var x var-x) (var y var-y) (var z var-z)))
           ;; The `float' forms in the result are just artifacts of Calc's
           ;; current solver; it should be fixed to produce exact (integral)
           ;; results in this case.
           '(vec (calcFunc-eq (var x var-x) (float 1 0))
                 (calcFunc-eq (var y var-y) (float -1 0))
                 (calcFunc-eq (var z var-z) 0))))
  ;;   x = y + 1
  ;;   x = y
  ;; has no solution
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (var x var-x) (+ (var y var-y) 1))
              (calcFunc-eq (var x var-x) (var y var-y)))
            '(vec (var x var-x) (var y var-y)))
           '(calcFunc-solve
             (vec
              (calcFunc-eq (var x var-x) (+ (var y var-y) 1))
              (calcFunc-eq (var x var-x) (var y var-y)))
             (vec (var x var-x) (var y var-y)))))
  ;;  x + y + z = 6
  ;;  x + y     = 3
  ;;  x - y     = 1
  ;; with the unique solution x=2, y=1, z=3
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (+ (+ (var x var-x) (var y var-y)) (var z var-z)) 6)
              (calcFunc-eq (+ (var x var-x) (var y var-y)) 3)
              (calcFunc-eq (- (var x var-x) (var y var-y)) 1))
            '(vec (var x var-x) (var y var-y) (var z var-z)))
           '(vec
             (calcFunc-eq (var x var-x) 2)
             (calcFunc-eq (var y var-y) 1)
             (calcFunc-eq (var z var-z) 3))))
  ;; x = 3
  ;; x + 4y^2 = 3                   (ok, so this one isn't linear)
  ;; with the unique (double) solution x=3, y=0
  (should (equal
           (calcFunc-solve
            '(vec
              (calcFunc-eq (var x var-x) 3)
              (calcFunc-eq (+ (var x var-x) (* 4 (^ (var y var-y) 2))) 3))
            '(vec (var x var-x) (var y var-y)))
           '(vec (calcFunc-eq (var x var-x) 3)
                 (calcFunc-eq (var y var-y) 0)))))

(ert-deftest calc-poly-div ()
  "Test polynomial division, and that the remainder is recorded in the trail."
  (with-current-buffer (calc-trail-buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)

      (calc-eval "2x**3+1" 'push)
      (calc-eval "x**2+2x" 'push)
      (calc-poly-div nil)
      (let ((tos (calc-top-n 1))
            (trail (buffer-string)))
        (calc-pop 0)
        (should (equal tos '(- (* 2 (var x var-x)) 4)))
        (should (equal trail "pdiv 2 * x - 4\nprem 8 * x + 1\n"))))))

(ert-deftest calc-Math-integerp ()
  (should (Math-integerp -7))
  (should (Math-integerp (ash 1 65)))
  (should-not (Math-integerp '(float 1 0)))
  (should-not (Math-integerp nil))

  (should (Math-num-integerp -7))
  (should (Math-num-integerp (ash 1 65)))
  (should (Math-num-integerp '(float 1 0)))
  (should-not (Math-num-integerp nil)))

(ert-deftest calc-matrix-determinant ()
  (should (equal (calcFunc-det '(vec (vec 3)))
                 3))
  (should (equal (calcFunc-det '(vec (vec 2 3) (vec 6 7)))
                 -4))
  (should (equal (calcFunc-det '(vec (vec 1 2 3) (vec 4 5 7) (vec 9 6 2)))
                 15))
  (should (equal (calcFunc-det '(vec (vec 0 5 7 3)
                                     (vec 0 0 2 0)
                                     (vec 1 2 3 4)
                                     (vec 0 0 0 3)))
                 30))
  (should (equal (calcFunc-det '(vec (vec (var a var-a))))
                 '(var a var-a)))
  (should (equal (calcFunc-det '(vec (vec 2 (var a var-a))
                                     (vec 7 (var a var-a))))
                 '(* -5 (var a var-a))))
  (should (equal (calcFunc-det '(vec (vec 1 0 0 0)
                                     (vec 0 1 0 0)
                                     (vec 0 0 0 1)
                                     (vec 0 0 (var a var-a) 0)))
                 '(neg (var a var-a)))))

(ert-deftest calc-gcd ()
  (should (equal (calcFunc-gcd 3 4) 1))
  (should (equal (calcFunc-gcd 12 15) 3))
  (should (equal (calcFunc-gcd -12 15) 3))
  (should (equal (calcFunc-gcd 12 -15) 3))
  (should (equal (calcFunc-gcd -12 -15) 3))
  (should (equal (calcFunc-gcd 0 5) 5))
  (should (equal (calcFunc-gcd 5 0) 5))
  (should (equal (calcFunc-gcd 0 -5) 5))
  (should (equal (calcFunc-gcd -5 0) 5))
  (should (equal (calcFunc-gcd 0 0) 0))
  (should (equal (calcFunc-gcd 0 '(var x var-x))
                 '(calcFunc-abs (var x var-x))))
  (should (equal (calcFunc-gcd '(var x var-x) 0)
                 '(calcFunc-abs (var x var-x)))))

(ert-deftest calc-sum-gcd ()
  ;; sum(gcd(0,n),n,-1,-1)
  (should (equal (math-simplify '(calcFunc-sum (calcFunc-gcd 0 (var n var-n))
                                               (var n var-n) -1 -1))
                 1))
  ;; sum(sum(gcd(n,k),k,-1,1),n,-1,1)
  (should (equal (math-simplify
                  '(calcFunc-sum
                    (calcFunc-sum (calcFunc-gcd (var n var-n) (var k var-k))
                                  (var k var-k) -1 1)
                    (var n var-n) -1 1))
                 8)))

(defun calc-tests--fac (n)
  (apply #'* (number-sequence 1 n)))

(defun calc-tests--choose (n k)
  "N choose K, reference implementation."
  (cond
   ((and (integerp n) (integerp k))
    (if (<= 0 n)
        (if (<= 0 k n)
            (/ (calc-tests--fac n)
               (* (calc-tests--fac k) (calc-tests--fac (- n k))))
          0)    ; 0≤n<k
      ;; n<0, n and k integers: use extension from M. J. Kronenburg
      (cond
       ((<= 0 k)
        (* (expt -1 k)
           (calc-tests--choose (+ (- n) k -1) k)))
       ((<= k n)
        (* (expt -1 (- n k))
           (calc-tests--choose (+ (- k) -1) (- n k))))
       (t  ; n<k<0
        0))))
   ((natnump k)
    ;; Generalisation for any n, integral k≥0: use falling product
    (/ (apply '* (number-sequence n (- n (1- k)) -1))
       (calc-tests--fac k)))
   (t (error "case not covered"))))

(defun calc-tests--check-choose (n k)
  (equal (calcFunc-choose n k)
         (calc-tests--choose n k)))

(defun calc-tests--explain-choose (n k)
  (let ((got (calcFunc-choose n k))
        (expected (calc-tests--choose n k)))
    (format "(calcFunc-choose %d %d) => %S, expected %S" n k got expected)))

(put 'calc-tests--check-choose 'ert-explainer 'calc-tests--explain-choose)

(defun calc-tests--calc-to-number (x)
  "Convert a Calc object to a Lisp number."
  (pcase x
    ((pred numberp) x)
    (`(frac ,p ,q) (/ (float p) q))
    (`(float ,m ,e) (* m (expt 10 e)))
    (_ (error "calc object not converted: %S" x))))

(ert-deftest calc-choose ()
  "Test computation of binomial coefficients (bug#16999)."
  ;; Integral arguments
  (dolist (n (number-sequence -6 6))
    (dolist (k (number-sequence -6 6))
      (should (calc-tests--check-choose n k))))

  ;; Fractional n, natural k
  (should (equal (calc-tests--calc-to-number
                  (calcFunc-choose '(frac 15 2) 3))
                 (calc-tests--choose 7.5 3)))

  (should (equal (calc-tests--calc-to-number
                  (calcFunc-choose '(frac 1 2) 2))
                 (calc-tests--choose 0.5 2)))

  (should (equal (calc-tests--calc-to-number
                  (calcFunc-choose '(frac -15 2) 3))
                 (calc-tests--choose -7.5 3))))

(provide 'calc-tests)
;;; calc-tests.el ends here

;; Local Variables:
;; bug-reference-url-format: "https://debbugs.gnu.org/%s"
;; End:
