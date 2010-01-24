/**
 * Copyright (c) 2009 Red Hat, Inc.
 *
 * This software is licensed to you under the GNU General Public License,
 * version 2 (GPLv2). There is NO WARRANTY for this software, express or
 * implied, including the implied warranties of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
 * along with this software; if not, see
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
 *
 * Red Hat trademarks are not licensed under GPLv2. No permission is
 * granted to use or replicate Red Hat trademarks that are incorporated
 * in this software or its documentation.
 */
package org.fedoraproject.candlepin.policy;

import java.util.LinkedList;
import java.util.List;

/**
 * Results of an enforcer validation. Basically used to support multiple 
 * errors being generated by an attempt to consume (perhaps multiple attribute 
 * checks failed), but also the possibility of warnings, which do not actually
 * prevent the entitlement from being given out.
 * 
 */
public class ValidationResult {
	
	private List<ValidationError> errors;
	private List<ValidationWarning> warnings;
	
	public ValidationResult() {
	    errors = new LinkedList<ValidationError>();
	    warnings = new LinkedList<ValidationWarning>();
	}

	public List<ValidationError> getErrors() {
		return errors;
	}
	
	public void addError(ValidationError error) {
		errors.add(error);
	}
	
	public void addError(String resourceKey) {
	    errors.add(new ValidationError(resourceKey));
	}

	public List<ValidationWarning> getWarnings() {
		return warnings;
	}
	
	public void addWarning(ValidationWarning warning) {
		warnings.add(warning);
	}

    public boolean hasErrors() {
        return !errors.isEmpty();
    }

    public boolean hasWarnings() {
        return !warnings.isEmpty();
    }

    public boolean isSuccessful() {
        return !hasErrors();
    }
}
