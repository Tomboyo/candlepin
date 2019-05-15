/**
 * Copyright (c) 2009 - 2018 Red Hat, Inc.
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
package org.candlepin.async;

import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;



/**
 * The JobConfig object collects the configuration for a job, which can be provided to the
 * JobManager to queue a new instance of that job.
 */
public class JobConfig {

    private String key;
    private String name;
    private String group;
    private Map<String, String> metadata;
    private Map<String, Object> arguments;
    private Set<JobConstraint> constraints;
    private int retries;
    private String logLevel;
    private boolean logExecutionDetails;

    /**
     * Creates an empty JobConfig
     */
    public JobConfig() {
        this.metadata = new HashMap<>();
        this.arguments = new HashMap<>();
        this.constraints = new HashSet<>();

        this.retries = 0;
        this.logExecutionDetails = true;
    }

    /**
     * Creates a new JobConfig for the specified asyncronous job task.
     *
     * @param jobKey
     *  The key representing the job class to handle execution of this job
     *
     * @return
     *  a new JobConfig instance for the specified job class
     */
    public static JobConfig forJob(String jobKey) {
        JobConfig config = new JobConfig();

        return config.setJobKey(jobKey);
    }

    /**
     * Sets the key for the job class to handle execution of this job. If the key does represent a
     * valid job class at the time of scheduling or execution, the job will permanently enter the
     * FAILED state.
     *
     * @param jobKey
     *  The key representing the job class to handle execution of this job
     *
     * @throws IllegalArgumentException
     *  if jobKey is null or empty
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setJobKey(String jobKey) {
        if (jobKey == null || jobKey.isEmpty()) {
            throw new IllegalArgumentException("jobKey is null or empty");
        }

        this.key = jobKey;
        return this;
    }

    /**
     * Fetches the job key set for this job
     *
     * @return
     *  the key representing the job class to handle execution of this job, or null if the job
     *  class has not yet been set
     */
    public String getJobKey() {
        return this.key;
    }

    /**
     * Sets the name of this job.
     *
     * @param jobName
     *  The name to set for this job
     *
     * @throws IllegalArgumentException
     *  if the job name is null or empty
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setJobName(String jobName) {
        if (jobName == null || jobName.isEmpty()) {
            throw new IllegalArgumentException("jobName is null or empty");
        }

        this.name = jobName;
        return this;
    }

    /**
     * Fetches the name of this job. If the job name has not yet been set, this method returns
     * null.
     *
     * @return
     *  The name of this job, or null if the name has not been set
     */
    public String getJobName() {
        return this.name;
    }

    /**
     * Sets the group name for this job.
     *
     * @param jobGroup
     *  The name of the group to set for this job
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setJobGroup(String jobGroup) {
        this.group = jobGroup != null && !jobGroup.isEmpty() ? jobGroup : null;
        return this;
    }

    /**
     * Fetches the group for this job. If the job group has not yet been set, this method returns
     * null.
     *
     * @return
     *  The group for this job, or null if the group has not been set
     */
    public String getJobGroup() {
        return this.group;
    }

    /**
     * Sets the value of an argument to pass into the job at the time of execution. As the value
     * may be serialized and deserialized before the job is executed, it is best to avoid setting
     * any values which are sensitive to transient data or have large trees of data.
     *
     * @param arg
     *  The name of the argument to pass to the job at the time of execution
     *
     * @param value
     *  The value of the argument
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setJobArgument(String arg, Object value) {
        if (arg == null) {
            throw new IllegalArgumentException("arg is null");
        }

        this.arguments.put(arg, value);
        return this;
    }

    /**
     * Fetches the arguments set for this job. If no arguments have been set for this job,
     * this method returns an empty map. Note that the map returned by this method cannot be
     * modified directly, though changes made to the arguments by this config will be reflected
     * in the returned map.
     *
     * @return
     *  a map of arguments to pass to the job at execution time
     */
    public Map<String, Object> getJobArguments() {
        return Collections.unmodifiableMap(this.arguments);
    }

    /**
     * Adds a queuing constraint to this job config. If the constraint has already been added, it
     * will not be added again.
     *
     * @param constraint
     *  the queuing constraint to add to this job
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig addConstraint(JobConstraint constraint) {
        if (constraint == null) {
            throw new IllegalArgumentException("constraint is null");
        }

        this.constraints.add(constraint);
        return this;
    }

    /**
     * Fetches the collection of queuing constraints to apply to this job. If this job does not have
     * any constraints, this method returns an empty collection.
     *
     * @return
     *  a collection of queuing constraints to apply to this job
     */
    public Collection<JobConstraint> getConstraints() {
        return Collections.unmodifiableSet(this.constraints);
    }

    /**
     * Sets the number of times this job will be retried if it fails to complete normally. Values
     * lower than 1 indicate the job will not be retried at all on failure.
     *
     * @param count
     *  The number of times the job should be retried on failure
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setRetryCount(int count) {
        this.retries = Math.max(0, count);
        return this;
    }

    /**
     * Fetches the number of times this job should be retried if it fails to complete successfully.
     *
     * @return
     *  The number of times this job should be retried, or zero if the job should not be retried
     */
    public int getRetryCount() {
        return this.retries;
    }

    /**
     * Fetches the log level with which this job will be executed. If the log level has not been
     * set, this method returns null.
     *
     * @return
     *  the log level for this job, or null if the log level has not been set
     */
    public String getLogLevel() {
        return this.logLevel;
    }

    /**
     * Sets the log level with which this job will be executed. If the log level is null or empty,
     * any existing log level will be cleared.
     *
     * @param logLevel
     *  the log level to set for this job, or null to clear it
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setLogLevel(String logLevel) {
        this.logLevel = logLevel != null && !logLevel.isEmpty() ? logLevel : null;
        return this;
    }

    /**
     * Fetches whether or not the execution details, such as job initialization and total runtime
     * upon successful completion, should be logged for this job.
     *
     * @return
     *  true if the execution details for this job should be logged; false otherwise
     */
    public boolean logExecutionDetails() {
        return this.logExecutionDetails;
    }

    /**
     * Sets whether or not the execution details, such as job initialization and total runtime
     * upon successful completion, should be logged for this job.
     *
     * @param enabled
     *  true to enable logging of execution details; false to disable it
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig logExecutionDetails(boolean enabled) {
        this.logExecutionDetails = enabled;
        return this;
    }

    /**
     * Adds or updates a metadata entry for this job.
     *
     * @param key
     *  The key for the metadata entry
     *
     * @param value
     *  The value of the metadata entry
     *
     * @return
     *  this JobConfig instance
     */
    public JobConfig setJobMetadata(String key, String value) {
        if (key == null) {
            throw new IllegalArgumentException("key is null");
        }

        this.metadata.put(key, value);
        return this;
    }

    /**
     * Fetches the metadata for this job. If the job does not have any metadata defined, this method
     * returns an empty map.
     *
     * @return
     *  the metadata for this job
     */
    public Map<String, String> getJobMetadata() {
        return Collections.unmodifiableMap(this.metadata);
    }

    /**
     * Validates whether or not this config is valid. By default, only the job key is required to
     * be a valid job configuration, but subclasses may have more specific requirements.
     *
     * @throws JobConfigValidationException
     *  if this config is incomplete or contains invalid values needed for the job to be queued and
     *  executed
     */
    public void validate() throws JobConfigValidationException {
        String key = this.getJobKey();
        if (key == null || key.isEmpty()) {
            throw new JobConfigValidationException("Job key is null or empty");
        }
    }


}