begin
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'PRETTY', true);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'STORAGE', false);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'TABLESPACE', false);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
    dbms_metadata.set_transform_param(dbms_metadata.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false, 'MATERIALIZED_VIEW');
end;
/

