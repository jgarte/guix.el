;;; guix-profiles.el --- Guix profiles

;; Copyright © 2014–2016 Alex Kost <alezost@gmail.com>
;; Copyright © 2015 Mathieu Lirzin <mthl@openmailbox.org>

;; This file is part of Emacs-Guix.

;; Emacs-Guix is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Emacs-Guix is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Emacs-Guix.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file provides a general code related to location and contents of
;; Guix profiles.

;;; Code:

(defvar guix-state-directory
  ;; guix-daemon honors `NIX_STATE_DIR'.
  (or (getenv "NIX_STATE_DIR") "/var/guix"))

(defvar guix-user-profile
  (expand-file-name "~/.guix-profile")
  "User profile.")

(defvar guix-system-profile
  (concat guix-state-directory "/profiles/system")
  "System profile.")

(defvar guix-default-profile
  (concat guix-state-directory
          "/profiles/per-user/"
          (getenv "USER")
          "/guix-profile")
  "Default Guix profile.")

(defvar guix-current-profile guix-default-profile
  "Current Guix profile.
It is used by various commands as the default working profile.")

(defvar guix-system-profile-regexp
  (rx-to-string `(and string-start
                      (or ,guix-system-profile
                          "/run/booted-system"
                          "/run/current-system"))
                t)
  "Regexp matching system profiles.")

(defun guix-system-profile? (profile)
  "Return non-nil, if PROFILE is a system one."
  (string-match-p guix-system-profile-regexp profile))

(defun guix-generation-file (profile generation)
  "Return the file name of a PROFILE's GENERATION."
  (format "%s-%s-link" profile generation))

(defun guix-profile (profile)
  "Return normalized file name of PROFILE.
\"Normalized\" means the returned file name is expanded, does not
have a trailing slash and it is `guix-default-profile' if PROFILE
is `guix-user-profile'.  `guix-user-profile' is special because
it is actually a symlink to a real user profile, and the HOME
directory does not contain profile generations."
  (let ((profile (directory-file-name (expand-file-name profile))))
    (if (string= profile guix-user-profile)
        guix-default-profile
      profile)))

(defun guix-generation-profile (profile &optional generation)
  "Return file name of PROFILE or its GENERATION.
The returned file name is the one that have generations in the
same parent directory.

If PROFILE matches `guix-system-profile-regexp', then it is
considered to be a system profile.  Unlike usual profiles, for a
system profile, packages are placed in 'profile' sub-directory,
so the returned file name does not contain this potential
trailing '/profile'."
  (let* ((profile (guix-profile profile))
         (profile (if (and (guix-system-profile? profile)
                           (string-match (rx (group (* any))
                                             "/profile" string-end)
                                         profile))
                      (match-string 1 profile)
                    profile)))
    (if generation
        (guix-generation-file profile generation)
      profile)))

(defun guix-package-profile (profile &optional generation)
  "Return file name of PROFILE or its GENERATION.
The returned file name is the one where packages are installed.

If PROFILE is a system one (see `guix-generation-profile'), then
the returned file name ends with '/profile'."
  (let* ((profile (guix-generation-profile profile))
         (profile (if generation
                      (guix-generation-file profile generation)
                    profile)))
    (if (guix-system-profile? profile)
        (expand-file-name "profile" profile)
      profile)))

(defun guix-manifest-file (profile &optional generation)
  "Return the file name of a PROFILE's manifest."
  (expand-file-name "manifest"
                    (guix-package-profile profile generation)))

(defun guix-profile-prompt (&optional default)
  "Prompt for profile and return it.
Use DEFAULT as a start directory.  If it is nil, use
`guix-current-profile'."
  (guix-package-profile
   (read-file-name "Profile: "
                   (file-name-directory
                    (or default guix-current-profile)))))

;;;###autoload
(defun guix-set-current-profile (file-name)
  "Set `guix-current-profile' to FILE-NAME.
Interactively, prompt for FILE-NAME.  With prefix, use
`guix-default-profile'."
  (interactive
   (list (if current-prefix-arg
             guix-default-profile
           (guix-profile-prompt))))
  (setq guix-current-profile file-name)
  (message "Current profile has been set to '%s'."
           guix-current-profile))

(provide 'guix-profiles)

;;; guix-profiles.el ends here
