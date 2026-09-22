-- Seed selling context conditions — medical device home monitoring domain.
--
-- Each row attaches one named condition to a selling context.
-- At runtime, ALL conditions for a context must be satisfied for that
-- context to match the incoming buyer request.
--
-- Test-case coverage:
--   sc-patient-direct     — single condition (channel = direct); simple match
--   sc-clinician-licensed — two conditions (channel + license-verified); tests AND logic
--   sc-distributor-cert   — two conditions (channel + partner-agreement); tests partner path
--
-- Column order: SELLING_CONTEXT_UID, CONDITION_GUID

INSERT INTO tsellingcontextcondition VALUES
--  SELLING_CONTEXT_UID  CONDITION_GUID
    -- Individual patient: direct channel only
    (10,                  'cond-channel-direct'),
    -- Licensed clinician: direct channel + valid clinical licence on file
    (20,                  'cond-channel-direct'),
    (20,                  'cond-license-verified'),
    -- Certified distributor: partner channel + signed distributor agreement
    (30,                  'cond-channel-partner'),
    (30,                  'cond-agreement-signed');
