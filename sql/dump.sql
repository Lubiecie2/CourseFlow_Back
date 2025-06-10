--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-06-10 10:06:43

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 5421 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- TOC entry 279 (class 1255 OID 98309)
-- Name: attach_partition(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.attach_partition(table_name text, year integer, month integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN

    partition_name := table_name || '_y' || year || LPAD(month::TEXT, 2, '0');
    
    PERFORM 1 FROM pg_tables WHERE tablename = partition_name;
    IF NOT FOUND THEN
        RETURN 'Tabela partycji nie istnieje: ' || partition_name;
    END IF;
    

    PERFORM 1 
    FROM pg_inherits i
    JOIN pg_class parent ON i.inhparent = parent.oid
    JOIN pg_class child ON i.inhrelid = child.oid
    WHERE parent.relname = table_name AND child.relname = partition_name;
    
    IF FOUND THEN
        RETURN 'Partycja jest już podłączona: ' || partition_name;
    END IF;
    
    start_date := make_date(year, month, 1);
    IF month = 12 THEN
        end_date := make_date(year + 1, 1, 1);
    ELSE
        end_date := make_date(year, month + 1, 1);
    END IF;
    
    EXECUTE format(
        'ALTER TABLE %I ATTACH PARTITION %I FOR VALUES FROM (%L) TO (%L)',
        table_name, partition_name, start_date, end_date
    );
    
    RETURN 'Podłączono partycję: ' || partition_name;
END;
$$;


ALTER FUNCTION public.attach_partition(table_name text, year integer, month integer) OWNER TO postgres;

--
-- TOC entry 294 (class 1255 OID 98310)
-- Name: create_monthly_partition(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_monthly_partition(table_name text, year integer, month integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN

    partition_name := table_name || '_y' || year || LPAD(month::TEXT, 2, '0');
    
    start_date := make_date(year, month, 1);
    IF month = 12 THEN
        end_date := make_date(year + 1, 1, 1);
    ELSE
        end_date := make_date(year, month + 1, 1);
    END IF;
    
    PERFORM 1 FROM pg_tables WHERE tablename = partition_name;
    IF FOUND THEN
        RETURN 'Partycja już istnieje: ' || partition_name;
    END IF;
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
        partition_name, table_name, start_date, end_date
    );
    
    EXECUTE format(
        'CREATE INDEX %I ON %I (user_id, created_at)',
        'idx_' || partition_name || '_user_id', 
        partition_name
    );
    
    EXECUTE format(
        'CREATE INDEX %I ON %I (action_type, created_at)',
        'idx_' || partition_name || '_action_type', 
        partition_name
    );
    
    RETURN 'Utworzono partycję: ' || partition_name;
END;
$$;


ALTER FUNCTION public.create_monthly_partition(table_name text, year integer, month integer) OWNER TO postgres;

--
-- TOC entry 295 (class 1255 OID 98311)
-- Name: detach_partition(text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.detach_partition(table_name text, year integer, month integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    partition_name TEXT;
BEGIN

    partition_name := table_name || '_y' || year || LPAD(month::TEXT, 2, '0');
    
    PERFORM 1 
    FROM pg_inherits i
    JOIN pg_class parent ON i.inhparent = parent.oid
    JOIN pg_class child ON i.inhrelid = child.oid
    WHERE parent.relname = table_name AND child.relname = partition_name;
    
    IF NOT FOUND THEN
        RETURN 'Partycja nie istnieje lub jest już odłączona: ' || partition_name;
    END IF;
    
    EXECUTE format('ALTER TABLE %I DETACH PARTITION %I', table_name, partition_name);
    
    RETURN 'Odłączono partycję: ' || partition_name;
END;
$$;


ALTER FUNCTION public.detach_partition(table_name text, year integer, month integer) OWNER TO postgres;

--
-- TOC entry 296 (class 1255 OID 98312)
-- Name: fn_notify_new_course(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_notify_new_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    CALL sp_create_new_course_notifications(NEW.id, NEW.title);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_notify_new_course() OWNER TO postgres;

--
-- TOC entry 297 (class 1255 OID 98313)
-- Name: get_current_user_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_current_user_id() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INTEGER;
BEGIN
    BEGIN
        user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        user_id := NULL;
    END;
    
    RETURN user_id;
END;
$$;


ALTER FUNCTION public.get_current_user_id() OWNER TO postgres;

--
-- TOC entry 298 (class 1255 OID 98314)
-- Name: log_course_delete_operation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_course_delete_operation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    BEGIN
        INSERT INTO course_logs (
            course_id,
            user_id,
            action_type,
            old_value,
            new_value,
            course_title,
            action_description,
            created_at
        ) VALUES (
            NULL,  
            get_current_user_id(),
            'COURSE_DELETED',
            NULL,   
            NULL,   
            OLD.title,
            'Course ID ' || OLD.id || ' deleted',
            now()
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Błąd w funkcji log_course_delete_operation: %', SQLERRM;
    END;
    
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.log_course_delete_operation() OWNER TO postgres;

--
-- TOC entry 299 (class 1255 OID 98315)
-- Name: log_course_operation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_course_operation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    action_type VARCHAR(50);
    old_value TEXT;
    new_value TEXT;
    description TEXT;
BEGIN

    IF TG_OP = 'INSERT' THEN
        action_type := 'COURSE_CREATED';
        old_value := NULL;
        new_value := NULL;
        description := 'Kurs utworzony';
    ELSIF TG_OP = 'UPDATE' THEN
        action_type := 'COURSE_UPDATED';
        
        IF OLD.title <> NEW.title THEN
            old_value := OLD.title;
            new_value := NEW.title;
            description := 'Zmiana tytułu z "' || OLD.title || '" na "' || NEW.title || '"';
        ELSIF OLD.short_description <> NEW.short_description THEN
            old_value := OLD.short_description;
            new_value := NEW.short_description;
            description := 'Zmiana opisu z "' || OLD.short_description || '" na "' || NEW.short_description || '"';
        ELSIF OLD.category <> NEW.category THEN
            old_value := OLD.category;
            new_value := NEW.category;
            description := 'Zmiana kategorii z "' || OLD.category || '" na "' || NEW.category || '"';
        ELSIF OLD.is_published <> NEW.is_published THEN
            old_value := CASE WHEN OLD.is_published THEN 'Opublikowany' ELSE 'Nieopublikowany' END;
            new_value := CASE WHEN NEW.is_published THEN 'Opublikowany' ELSE 'Nieopublikowany' END;
            description := 'Zmiana statusu publikacji z "' || 
                          CASE WHEN OLD.is_published THEN 'Opublikowany' ELSE 'Nieopublikowany' END || 
                          '" na "' || 
                          CASE WHEN NEW.is_published THEN 'Opublikowany' ELSE 'Nieopublikowany' END || '"';
        ELSE
            old_value := NULL;
            new_value := NULL;
            description := 'Kurs zaktualizowany';
        END IF;
    END IF;
    BEGIN
        INSERT INTO course_logs (
            course_id,
            user_id,
            action_type,
            old_value,
            new_value,
            course_title,
            action_description,
            created_at
        ) VALUES (
            NEW.id,
            get_current_user_id(),
            action_type,
            old_value,
            new_value,
            NEW.title,
            description,
            now()
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Błąd w funkcji log_course_operation: %', SQLERRM;
    END;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_course_operation() OWNER TO postgres;

--
-- TOC entry 300 (class 1255 OID 98316)
-- Name: log_user_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_user_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    admin_id INTEGER;
    user_email TEXT;
BEGIN

    BEGIN

        SELECT NULLIF(current_setting('app.current_user_id', TRUE), '')::INTEGER INTO STRICT admin_id;
    EXCEPTION WHEN OTHERS THEN

        admin_id := NULL;
    END;

    user_email := OLD.email;

    INSERT INTO user_logs (
        action_type,
        user_id,
        changed_by_user_id,
        old_value,
        new_value
    ) VALUES (
        'USER_DELETED',
        NULL,  
        admin_id, 
        user_email,  
        NULL
    );

    RETURN OLD;
END;
$$;


ALTER FUNCTION public.log_user_delete() OWNER TO postgres;

--
-- TOC entry 301 (class 1255 OID 98317)
-- Name: log_user_operation(integer, character varying, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_user_operation(p_user_id integer, p_action_type character varying, p_old_value text, p_new_value text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    log_id INTEGER;
    changed_by INTEGER;
BEGIN

    SELECT current_setting('app.current_user_id', TRUE)::INTEGER INTO changed_by;
    
    INSERT INTO user_logs(
        user_id,
        changed_by_user_id,
        action_type,
        old_value,
        new_value
    ) VALUES (
        p_user_id,
        changed_by,
        p_action_type,
        p_old_value,
        p_new_value
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$;


ALTER FUNCTION public.log_user_operation(p_user_id integer, p_action_type character varying, p_old_value text, p_new_value text) OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 98318)
-- Name: role_changed_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.role_changed_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_role_name TEXT;
    new_role_name TEXT;
BEGIN
    IF OLD.role_id = NEW.role_id THEN
        RETURN NEW;
    END IF;
    
    SELECT name INTO old_role_name FROM roles WHERE id = OLD.role_id;
    SELECT name INTO new_role_name FROM roles WHERE id = NEW.role_id;
    
    PERFORM log_user_operation(
        NEW.id,
        'ROLE_CHANGED',
        old_role_name,
        new_role_name
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.role_changed_trigger() OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 98319)
-- Name: set_operation_context(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_operation_context(user_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF user_id IS NOT NULL THEN
        PERFORM set_config('app.current_user_id', user_id::text, false);
    END IF;
END;
$$;


ALTER FUNCTION public.set_operation_context(user_id integer) OWNER TO postgres;

--
-- TOC entry 281 (class 1255 OID 98320)
-- Name: sp_create_new_course_notifications(integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_create_new_course_notifications(IN p_course_id integer, IN p_course_title character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_record RECORD;
BEGIN

    FOR user_record IN SELECT id FROM users
    LOOP
        INSERT INTO notifications(
            user_id, 
            title, 
            message, 
            type, 
            related_entity_id
        ) VALUES (
            user_record.id,
            'Nowy kurs dostępny!',
            'Nowy kurs "' || p_course_title || '" jest już dostępny na platformie.',
            'NEW_COURSE',
            p_course_id
        );
    END LOOP;
END;
$$;


ALTER PROCEDURE public.sp_create_new_course_notifications(IN p_course_id integer, IN p_course_title character varying) OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 98321)
-- Name: user_deleted_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_deleted_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    PERFORM log_user_operation(
        OLD.id,
        'USER_DELETED',
        OLD.email, 
        NULL
    );
    
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.user_deleted_trigger() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 217 (class 1259 OID 98322)
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 98329)
-- Name: answer_attributes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.answer_attributes (
    id integer NOT NULL,
    answer_id integer NOT NULL,
    attribute_name character varying(100) NOT NULL,
    attribute_value text
);


ALTER TABLE public.answer_attributes OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 98334)
-- Name: answer_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.answer_attributes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.answer_attributes_id_seq OWNER TO postgres;

--
-- TOC entry 5423 (class 0 OID 0)
-- Dependencies: 219
-- Name: answer_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.answer_attributes_id_seq OWNED BY public.answer_attributes.id;


--
-- TOC entry 220 (class 1259 OID 98335)
-- Name: certificates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificates (
    id integer NOT NULL,
    user_id integer,
    course_id integer,
    certificate_code character varying(20) NOT NULL,
    issued_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    pdf_url text,
    status character varying(20) DEFAULT 'issued'::character varying
);


ALTER TABLE public.certificates OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 98342)
-- Name: certificates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.certificates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.certificates_id_seq OWNER TO postgres;

--
-- TOC entry 5424 (class 0 OID 0)
-- Dependencies: 221
-- Name: certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificates_id_seq OWNED BY public.certificates.id;


--
-- TOC entry 222 (class 1259 OID 98343)
-- Name: chapter_block_attributes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chapter_block_attributes (
    id integer NOT NULL,
    block_id integer NOT NULL,
    name character varying(50) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.chapter_block_attributes OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 98348)
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chapter_block_attributes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chapter_block_attributes_id_seq OWNER TO postgres;

--
-- TOC entry 5425 (class 0 OID 0)
-- Dependencies: 223
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_block_attributes_id_seq OWNED BY public.chapter_block_attributes.id;


--
-- TOC entry 224 (class 1259 OID 98349)
-- Name: chapter_blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chapter_blocks (
    id integer NOT NULL,
    chapter_id integer NOT NULL,
    type character varying(50) NOT NULL,
    content text,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.chapter_blocks OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 98357)
-- Name: chapter_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chapter_blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chapter_blocks_id_seq OWNER TO postgres;

--
-- TOC entry 5426 (class 0 OID 0)
-- Dependencies: 225
-- Name: chapter_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_blocks_id_seq OWNED BY public.chapter_blocks.id;


--
-- TOC entry 226 (class 1259 OID 98358)
-- Name: chapters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chapters (
    id integer NOT NULL,
    course_id integer,
    title character varying(255) NOT NULL,
    wysiwyg_code text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.chapters OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 98365)
-- Name: chapters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chapters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chapters_id_seq OWNER TO postgres;

--
-- TOC entry 5427 (class 0 OID 0)
-- Dependencies: 227
-- Name: chapters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapters_id_seq OWNED BY public.chapters.id;


--
-- TOC entry 228 (class 1259 OID 98366)
-- Name: course_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_answers (
    id integer NOT NULL,
    content text NOT NULL,
    user_id integer NOT NULL,
    question_id integer NOT NULL,
    is_accepted boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.course_answers OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 98374)
-- Name: course_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_answers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_answers_id_seq OWNER TO postgres;

--
-- TOC entry 5428 (class 0 OID 0)
-- Dependencies: 229
-- Name: course_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_answers_id_seq OWNED BY public.course_answers.id;


--
-- TOC entry 230 (class 1259 OID 98375)
-- Name: course_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_logs (
    id integer NOT NULL,
    course_id integer,
    user_id integer,
    action_type character varying(50) NOT NULL,
    old_value text,
    new_value text,
    course_title character varying(255),
    action_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.course_logs OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 98379)
-- Name: course_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_logs_id_seq OWNER TO postgres;

--
-- TOC entry 5429 (class 0 OID 0)
-- Dependencies: 231
-- Name: course_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_logs_id_seq OWNED BY public.course_logs.id;


--
-- TOC entry 232 (class 1259 OID 98380)
-- Name: course_logs_y202505; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_logs_y202505 (
    id integer DEFAULT nextval('public.course_logs_id_seq'::regclass) NOT NULL,
    course_id integer,
    user_id integer,
    action_type character varying(50) NOT NULL,
    old_value text,
    new_value text,
    course_title character varying(255),
    action_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.course_logs_y202505 OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 98387)
-- Name: course_logs_y202506; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_logs_y202506 (
    id integer DEFAULT nextval('public.course_logs_id_seq'::regclass) NOT NULL,
    course_id integer,
    user_id integer,
    action_type character varying(50) NOT NULL,
    old_value text,
    new_value text,
    course_title character varying(255),
    action_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.course_logs_y202506 OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 98394)
-- Name: course_logs_y202507; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_logs_y202507 (
    id integer DEFAULT nextval('public.course_logs_id_seq'::regclass) NOT NULL,
    course_id integer,
    user_id integer,
    action_type character varying(50) NOT NULL,
    old_value text,
    new_value text,
    course_title character varying(255),
    action_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.course_logs_y202507 OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 98401)
-- Name: course_logs_y202508; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_logs_y202508 (
    id integer DEFAULT nextval('public.course_logs_id_seq'::regclass) NOT NULL,
    course_id integer,
    user_id integer,
    action_type character varying(50) NOT NULL,
    old_value text,
    new_value text,
    course_title character varying(255),
    action_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.course_logs_y202508 OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 98408)
-- Name: course_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_notes (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    user_id integer NOT NULL,
    course_id integer,
    file_path character varying(255),
    file_name character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.course_notes OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 98415)
-- Name: course_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_notes_id_seq OWNER TO postgres;

--
-- TOC entry 5430 (class 0 OID 0)
-- Dependencies: 237
-- Name: course_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_notes_id_seq OWNED BY public.course_notes.id;


--
-- TOC entry 238 (class 1259 OID 98416)
-- Name: course_questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_questions (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    user_id integer NOT NULL,
    course_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    views integer DEFAULT 0
);


ALTER TABLE public.course_questions OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 98424)
-- Name: course_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_questions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_questions_id_seq OWNER TO postgres;

--
-- TOC entry 5431 (class 0 OID 0)
-- Dependencies: 239
-- Name: course_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_questions_id_seq OWNED BY public.course_questions.id;


--
-- TOC entry 240 (class 1259 OID 98425)
-- Name: courses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.courses (
    id integer NOT NULL,
    user_id integer,
    title character varying(255) NOT NULL,
    short_description text,
    course_image text,
    category character varying(255),
    is_published boolean DEFAULT false,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.courses OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 98433)
-- Name: courses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.courses_id_seq OWNER TO postgres;

--
-- TOC entry 5432 (class 0 OID 0)
-- Dependencies: 241
-- Name: courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.courses_id_seq OWNED BY public.courses.id;


--
-- TOC entry 242 (class 1259 OID 98434)
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    type character varying(50) NOT NULL,
    related_entity_id integer,
    created_at timestamp with time zone DEFAULT now(),
    is_read boolean DEFAULT false
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 98441)
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- TOC entry 5433 (class 0 OID 0)
-- Dependencies: 243
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- TOC entry 244 (class 1259 OID 98442)
-- Name: permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.permissions OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 98449)
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO postgres;

--
-- TOC entry 5434 (class 0 OID 0)
-- Dependencies: 245
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- TOC entry 246 (class 1259 OID 98450)
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.role_permissions (
    role_id integer NOT NULL,
    permission_id integer NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.role_permissions OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 98455)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 98462)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO postgres;

--
-- TOC entry 5435 (class 0 OID 0)
-- Dependencies: 248
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- TOC entry 249 (class 1259 OID 98463)
-- Name: test_block_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_block_answers (
    id integer NOT NULL,
    block_id integer NOT NULL,
    answer_text text NOT NULL,
    is_correct boolean DEFAULT false,
    feedback text,
    sort_order integer DEFAULT 0
);


ALTER TABLE public.test_block_answers OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 98470)
-- Name: test_block_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_block_answers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_block_answers_id_seq OWNER TO postgres;

--
-- TOC entry 5436 (class 0 OID 0)
-- Dependencies: 250
-- Name: test_block_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_block_answers_id_seq OWNED BY public.test_block_answers.id;


--
-- TOC entry 251 (class 1259 OID 98471)
-- Name: test_block_attributes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_block_attributes (
    id integer NOT NULL,
    block_id integer NOT NULL,
    attribute_name character varying(100) NOT NULL,
    attribute_value text
);


ALTER TABLE public.test_block_attributes OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 98476)
-- Name: test_block_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_block_attributes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_block_attributes_id_seq OWNER TO postgres;

--
-- TOC entry 5437 (class 0 OID 0)
-- Dependencies: 252
-- Name: test_block_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_block_attributes_id_seq OWNED BY public.test_block_attributes.id;


--
-- TOC entry 253 (class 1259 OID 98477)
-- Name: test_blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_blocks (
    id integer NOT NULL,
    test_id integer NOT NULL,
    block_type character varying(50) NOT NULL,
    question_text text NOT NULL,
    points integer DEFAULT 1,
    sort_order integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.test_blocks OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 98486)
-- Name: test_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_blocks_id_seq OWNER TO postgres;

--
-- TOC entry 5438 (class 0 OID 0)
-- Dependencies: 254
-- Name: test_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_blocks_id_seq OWNED BY public.test_blocks.id;


--
-- TOC entry 255 (class 1259 OID 98487)
-- Name: tests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tests (
    id integer NOT NULL,
    chapter_id integer,
    course_id integer NOT NULL,
    author_id integer,
    title character varying(255) NOT NULL,
    description text,
    pass_threshold integer DEFAULT 70,
    time_limit integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_course_final boolean DEFAULT false
);


ALTER TABLE public.tests OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 98497)
-- Name: tests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tests_id_seq OWNER TO postgres;

--
-- TOC entry 5439 (class 0 OID 0)
-- Dependencies: 256
-- Name: tests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tests_id_seq OWNED BY public.tests.id;


--
-- TOC entry 257 (class 1259 OID 98498)
-- Name: user_chapter; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_chapter (
    id integer NOT NULL,
    user_id integer,
    chapter_id integer,
    is_completed boolean DEFAULT false,
    last_viewed timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_chapter OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 98503)
-- Name: user_chapter_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_chapter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_chapter_id_seq OWNER TO postgres;

--
-- TOC entry 5440 (class 0 OID 0)
-- Dependencies: 258
-- Name: user_chapter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_chapter_id_seq OWNED BY public.user_chapter.id;


--
-- TOC entry 259 (class 1259 OID 98504)
-- Name: user_courses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_courses (
    id integer NOT NULL,
    user_id integer,
    course_id integer,
    progress numeric(5,2) DEFAULT 0,
    status character varying(50) DEFAULT 'not_started'::character varying,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_courses OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 98510)
-- Name: user_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_courses_id_seq OWNER TO postgres;

--
-- TOC entry 5441 (class 0 OID 0)
-- Dependencies: 260
-- Name: user_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_courses_id_seq OWNED BY public.user_courses.id;


--
-- TOC entry 261 (class 1259 OID 98511)
-- Name: user_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs (
    id integer NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.user_logs OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 98515)
-- Name: user_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_logs_id_seq OWNER TO postgres;

--
-- TOC entry 5442 (class 0 OID 0)
-- Dependencies: 262
-- Name: user_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_logs_id_seq OWNED BY public.user_logs.id;


--
-- TOC entry 263 (class 1259 OID 98516)
-- Name: user_logs_y202505; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs_y202505 (
    id integer DEFAULT nextval('public.user_logs_id_seq'::regclass) NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_logs_y202505 OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 98523)
-- Name: user_logs_y202506; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs_y202506 (
    id integer DEFAULT nextval('public.user_logs_id_seq'::regclass) NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_logs_y202506 OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 98530)
-- Name: user_logs_y202507; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs_y202507 (
    id integer DEFAULT nextval('public.user_logs_id_seq'::regclass) NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_logs_y202507 OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 98537)
-- Name: user_logs_y202508; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs_y202508 (
    id integer DEFAULT nextval('public.user_logs_id_seq'::regclass) NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_logs_y202508 OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 98544)
-- Name: user_logs_y202509; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_logs_y202509 (
    id integer DEFAULT nextval('public.user_logs_id_seq'::regclass) NOT NULL,
    action_type character varying(50) NOT NULL,
    user_id integer,
    changed_by_user_id integer,
    old_value text,
    new_value text,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_logs_y202509 OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 98551)
-- Name: user_test_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_test_answers (
    id integer NOT NULL,
    attempt_id integer NOT NULL,
    block_id integer NOT NULL,
    selected_answer_id integer,
    text_answer text,
    json_answer jsonb,
    is_correct boolean DEFAULT false,
    points_awarded integer DEFAULT 0
);


ALTER TABLE public.user_test_answers OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 98558)
-- Name: user_test_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_test_answers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_test_answers_id_seq OWNER TO postgres;

--
-- TOC entry 5443 (class 0 OID 0)
-- Dependencies: 269
-- Name: user_test_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_test_answers_id_seq OWNED BY public.user_test_answers.id;


--
-- TOC entry 270 (class 1259 OID 98559)
-- Name: user_test_attempts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_test_attempts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    test_id integer NOT NULL,
    start_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    end_time timestamp without time zone,
    score integer DEFAULT 0,
    max_score integer DEFAULT 0,
    passed boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_test_attempts OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 98567)
-- Name: user_test_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_test_attempts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_test_attempts_id_seq OWNER TO postgres;

--
-- TOC entry 5444 (class 0 OID 0)
-- Dependencies: 271
-- Name: user_test_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_test_attempts_id_seq OWNED BY public.user_test_attempts.id;


--
-- TOC entry 272 (class 1259 OID 98568)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password text NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    role_id integer DEFAULT 2,
    is_verified boolean DEFAULT false,
    verification_token_id integer,
    reset_password_token character varying(255),
    reset_password_expires time(6) without time zone,
    last_password_change time(6) without time zone,
    first_login boolean DEFAULT true,
    last_login timestamp without time zone
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 98578)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5445 (class 0 OID 0)
-- Dependencies: 273
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 274 (class 1259 OID 98579)
-- Name: verification_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verification_tokens (
    id integer NOT NULL,
    user_id integer,
    verification_token character varying(255) NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp(6) without time zone
);


ALTER TABLE public.verification_tokens OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 98583)
-- Name: verification_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.verification_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.verification_tokens_id_seq OWNER TO postgres;

--
-- TOC entry 5446 (class 0 OID 0)
-- Dependencies: 275
-- Name: verification_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_tokens_id_seq OWNED BY public.verification_tokens.id;


--
-- TOC entry 276 (class 1259 OID 98584)
-- Name: waf_security_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.waf_security_events (
    id integer NOT NULL,
    event_id character varying(255) NOT NULL,
    event_type character varying(50) NOT NULL,
    ip_address character varying(45) NOT NULL,
    endpoint character varying(255),
    user_agent text,
    description text NOT NULL,
    risk_level character varying(20) DEFAULT 'medium'::character varying,
    action_taken character varying(50) DEFAULT 'blocked'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.waf_security_events OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 98592)
-- Name: waf_security_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.waf_security_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.waf_security_events_id_seq OWNER TO postgres;

--
-- TOC entry 5447 (class 0 OID 0)
-- Dependencies: 277
-- Name: waf_security_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.waf_security_events_id_seq OWNED BY public.waf_security_events.id;


--
-- TOC entry 4872 (class 0 OID 0)
-- Name: course_logs_y202505; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202505 FOR VALUES FROM ('2025-05-01 00:00:00') TO ('2025-06-01 00:00:00');


--
-- TOC entry 4873 (class 0 OID 0)
-- Name: course_logs_y202506; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202506 FOR VALUES FROM ('2025-06-01 00:00:00') TO ('2025-07-01 00:00:00');


--
-- TOC entry 4874 (class 0 OID 0)
-- Name: course_logs_y202507; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202507 FOR VALUES FROM ('2025-07-01 00:00:00') TO ('2025-08-01 00:00:00');


--
-- TOC entry 4875 (class 0 OID 0)
-- Name: course_logs_y202508; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202508 FOR VALUES FROM ('2025-08-01 00:00:00') TO ('2025-09-01 00:00:00');


--
-- TOC entry 4876 (class 0 OID 0)
-- Name: user_logs_y202505; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202505 FOR VALUES FROM ('2025-05-01 00:00:00') TO ('2025-06-01 00:00:00');


--
-- TOC entry 4877 (class 0 OID 0)
-- Name: user_logs_y202506; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202506 FOR VALUES FROM ('2025-06-01 00:00:00') TO ('2025-07-01 00:00:00');


--
-- TOC entry 4878 (class 0 OID 0)
-- Name: user_logs_y202507; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202507 FOR VALUES FROM ('2025-07-01 00:00:00') TO ('2025-08-01 00:00:00');


--
-- TOC entry 4879 (class 0 OID 0)
-- Name: user_logs_y202508; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202508 FOR VALUES FROM ('2025-08-01 00:00:00') TO ('2025-09-01 00:00:00');


--
-- TOC entry 4880 (class 0 OID 0)
-- Name: user_logs_y202509; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202509 FOR VALUES FROM ('2025-09-01 00:00:00') TO ('2025-10-01 00:00:00');


--
-- TOC entry 4883 (class 2604 OID 98593)
-- Name: answer_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes ALTER COLUMN id SET DEFAULT nextval('public.answer_attributes_id_seq'::regclass);


--
-- TOC entry 4884 (class 2604 OID 98594)
-- Name: certificates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates ALTER COLUMN id SET DEFAULT nextval('public.certificates_id_seq'::regclass);


--
-- TOC entry 4887 (class 2604 OID 98595)
-- Name: chapter_block_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes ALTER COLUMN id SET DEFAULT nextval('public.chapter_block_attributes_id_seq'::regclass);


--
-- TOC entry 4888 (class 2604 OID 98596)
-- Name: chapter_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks ALTER COLUMN id SET DEFAULT nextval('public.chapter_blocks_id_seq'::regclass);


--
-- TOC entry 4892 (class 2604 OID 98597)
-- Name: chapters id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters ALTER COLUMN id SET DEFAULT nextval('public.chapters_id_seq'::regclass);


--
-- TOC entry 4895 (class 2604 OID 98598)
-- Name: course_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers ALTER COLUMN id SET DEFAULT nextval('public.course_answers_id_seq'::regclass);


--
-- TOC entry 4899 (class 2604 OID 98599)
-- Name: course_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ALTER COLUMN id SET DEFAULT nextval('public.course_logs_id_seq'::regclass);


--
-- TOC entry 4909 (class 2604 OID 98600)
-- Name: course_notes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_notes ALTER COLUMN id SET DEFAULT nextval('public.course_notes_id_seq'::regclass);


--
-- TOC entry 4912 (class 2604 OID 98601)
-- Name: course_questions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions ALTER COLUMN id SET DEFAULT nextval('public.course_questions_id_seq'::regclass);


--
-- TOC entry 4916 (class 2604 OID 98602)
-- Name: courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses ALTER COLUMN id SET DEFAULT nextval('public.courses_id_seq'::regclass);


--
-- TOC entry 4920 (class 2604 OID 98603)
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- TOC entry 4923 (class 2604 OID 98604)
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- TOC entry 4928 (class 2604 OID 98605)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 4931 (class 2604 OID 98606)
-- Name: test_block_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers ALTER COLUMN id SET DEFAULT nextval('public.test_block_answers_id_seq'::regclass);


--
-- TOC entry 4934 (class 2604 OID 98607)
-- Name: test_block_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes ALTER COLUMN id SET DEFAULT nextval('public.test_block_attributes_id_seq'::regclass);


--
-- TOC entry 4935 (class 2604 OID 98608)
-- Name: test_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks ALTER COLUMN id SET DEFAULT nextval('public.test_blocks_id_seq'::regclass);


--
-- TOC entry 4940 (class 2604 OID 98609)
-- Name: tests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests ALTER COLUMN id SET DEFAULT nextval('public.tests_id_seq'::regclass);


--
-- TOC entry 4946 (class 2604 OID 98610)
-- Name: user_chapter id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter ALTER COLUMN id SET DEFAULT nextval('public.user_chapter_id_seq'::regclass);


--
-- TOC entry 4949 (class 2604 OID 98611)
-- Name: user_courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses ALTER COLUMN id SET DEFAULT nextval('public.user_courses_id_seq'::regclass);


--
-- TOC entry 4953 (class 2604 OID 98612)
-- Name: user_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ALTER COLUMN id SET DEFAULT nextval('public.user_logs_id_seq'::regclass);


--
-- TOC entry 4965 (class 2604 OID 98613)
-- Name: user_test_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers ALTER COLUMN id SET DEFAULT nextval('public.user_test_answers_id_seq'::regclass);


--
-- TOC entry 4968 (class 2604 OID 98614)
-- Name: user_test_attempts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts ALTER COLUMN id SET DEFAULT nextval('public.user_test_attempts_id_seq'::regclass);


--
-- TOC entry 4974 (class 2604 OID 98615)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4980 (class 2604 OID 98616)
-- Name: verification_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens ALTER COLUMN id SET DEFAULT nextval('public.verification_tokens_id_seq'::regclass);


--
-- TOC entry 4982 (class 2604 OID 98617)
-- Name: waf_security_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waf_security_events ALTER COLUMN id SET DEFAULT nextval('public.waf_security_events_id_seq'::regclass);


--
-- TOC entry 5357 (class 0 OID 98322)
-- Dependencies: 217
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
cc8802ab-4ab7-4a55-9878-b5bb0f0013ac	eb03430e2cb43c27ddd6f5f881c349e32ddfc9e63234f316bb90527d1b35c187	2025-04-06 19:58:41.165818+02	20250406175841_migracja1	\N	\N	2025-04-06 19:58:41.082249+02	1
\.


--
-- TOC entry 5358 (class 0 OID 98329)
-- Dependencies: 218
-- Data for Name: answer_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.answer_attributes (id, answer_id, attribute_name, attribute_value) FROM stdin;
6	95	right_item	M4
7	96	right_item	Stringer
8	97	right_item	RS5
9	98	right_item	CLA
10	99	right_item	1
11	100	right_item	2
12	101	right_item	3
19	136	right_item	Kierunek ramion paraboli
20	137	right_item	Wpływ na położenie wierzchołka
21	138	right_item	Punkt przecięcia z osią y
22	139	right_item	Dyskryminanta
23	151	right_item	Punkt przecięcia z osią y
24	152	right_item	Współrzędne wierzchołka
25	153	right_item	Miejsca zerowe
26	154	right_item	Technika przekształcania
27	162	right_item	Dwa różne pierwiastki
28	163	right_item	Jeden pierwiastek podwójny
29	164	right_item	Brak rozwiązań rzeczywistych
30	165	right_item	Związek pierwiastków ze współczynnikami
\.


--
-- TOC entry 5360 (class 0 OID 98335)
-- Dependencies: 220
-- Data for Name: certificates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificates (id, user_id, course_id, certificate_code, issued_at, pdf_url, status) FROM stdin;
28	82	1	CF-AE0D62F0	2025-06-05 13:50:34.53	/uploads/certificates/CF-AE0D62F0.pdf	issued
\.


--
-- TOC entry 5362 (class 0 OID 98343)
-- Dependencies: 222
-- Data for Name: chapter_block_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapter_block_attributes (id, block_id, name, value) FROM stdin;
52	52	content	dddddddddddddddddddddddddddddddd
53	53	content	Jwqeeeeeeeeeeraktywnych elementów na stronach internetowych.
141	141	content	treść akapitu
142	142	content	Treść
143	143	content	32422
144	144	content	Qwerty\n\n
145	145	content	Podstawy JavaScript - zaktualizowany tytuł
115354	50134	content	Równanie kwadratowe to równanie postaci a x kwadrat plus b x plus c równa się zero, gdzie a różne od zera. Rozwiązywanie równań kwadratowych to fundamentalna umiejętność w matematyce, która ma liczne zastosowania praktyczne.
115355	50134	format	
115356	50135	content	Podstawowym narzędziem do rozwiązywania równań kwadratowych jest wzór na deltę, czyli dyskryminantę: delta równa się b kwadrat minus cztery a c. Wartość delty determinuje liczbę i rodzaj rozwiązań równania kwadratowego.
115357	50135	format	
115358	50136	content	Gdy delta jest większa od zera, równanie ma dwa różne rozwiązania rzeczywiste, które obliczamy ze wzoru: x jeden równa się minus b plus pierwiastek z delty przez dwa a, x dwa równa się minus b minus pierwiastek z delty przez dwa a.
123060	53520	content	Lorem ipsum
123061	53520	format	,text-center,text-2xl
123062	53521	content	Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.
123063	53521	format	text-lg
123064	53522	content	Lorem ipsum dolor sit amet consectetur adipiscing elit. \nQuisque faucibus ex sapien vitae pellentesque sem placerat. \nIn id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. \nPulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. \nUt hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.
123065	53522	language	csharp
123066	53522	caption	Lorem ipsum
123067	53522	showLineNumbers	true
123068	53522	format	
123069	53523	src	http://localhost:4000/uploads/video-1745869505030-873262995.mp4
123070	53523	caption	
123071	53523	format	video-md,text-center
123072	53524	src	http://localhost:4000/uploads/image-1745325157490-688331706.jpg
123073	53524	alt	lfndtoirttvx.jpg
123074	53524	caption	
123075	53524	format	text-center,image-sm
123076	53524	content	
123077	53525	items	Lorem ipsum,dolor sit amet consectetur adipiscing elit,Quisque faucibus ex sapien vitae pellentesque sem placerat,In id cursus mi pretium tellus duis convallis.
123078	53525	type	unordered
123079	53525	format	text-base
115359	50136	format	
115360	50137	content	Gdy delta równa się zero, równanie ma jedno rozwiązanie rzeczywiste o krotności dwa, zwane pierwiastkiem podwójnym: x równa się minus b przez dwa a. Geometrycznie oznacza to, że parabola jest styczna do osi x w jednym punkcie.
115361	50137	format	
115362	50138	content	Gdy delta jest mniejsza od zera, równanie nie ma rozwiązań rzeczywistych. Parabola nie przecina osi x, lecz znajduje się całkowicie ponad nią gdy a większe od zera lub pod nią gdy a mniejsze od zera.
115363	50138	format	
115364	50139	content	Alternatywne metody rozwiązywania równań kwadratowych obejmują rozkład na czynniki, uzupełnianie do kwadratu oraz metody graficzne. Rozkład na czynniki jest szczególnie efektywny, gdy współczynniki równania pozwalają na łatwe wyodrębnienie wspólnych czynników.
115365	50139	format	
115366	50140	content	Wzory Vieta łączą pierwiastki równania kwadratowego z jego współczynnikami. Dla równania ax kwadrat plus bx plus c równa się zero, jeśli x jeden i x dwa to pierwiastki, to: x jeden plus x dwa równa się minus b przez a, x jeden razy x dwa równa się c przez a.
115367	50140	format	
123080	53526	content	Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor
123081	53526	format	,text-green,text-xl,font-bold,italic
123082	53527	content	Lorem ipsum
123083	53527	format	,text-red,text-right,text-xl
118668	51753	content	
118669	51753	format	
118670	51754	content	
115378	50146	content	Funkcję kwadratową możemy zapisać w trzech równoważnych postaciach, z których każda ma swoje zastosowania i zalety w różnych sytuacjach obliczeniowych.
115379	50146	format	
115380	50147	content	Postać ogólna to najbardziej podstawowa forma zapisu funkcji kwadratowej: f(x) równa się a x kwadrat plus b x plus c. Jest to forma wyjściowa, z której możemy bezpośrednio odczytać współczynniki a, b i c oraz punkt przecięcia z osią y, który wynosi c.
115381	50147	format	
115382	50148	content	Postać kanoniczna, zwana również postacią wierzchołkową, ma postać: f(x) równa się a razy x minus p całość do kwadratu plus q, gdzie p i q to współrzędne wierzchołka paraboli. Ta postać jest szczególnie użyteczna przy analizie przekształceń geometrycznych paraboli oraz przy określaniu ekstremum funkcji.
115383	50148	format	
115384	50149	content	Postać iloczynowa wykorzystuje miejsca zerowe funkcji i ma postać: f(x) równa się a razy x minus x jeden razy x minus x dwa, gdzie x jeden i x dwa to miejsca zerowe funkcji. Ta postać istnieje tylko wtedy, gdy funkcja ma miejsca zerowe rzeczywiste, czyli gdy dyskryminanta jest większa lub równa zero.
115385	50149	format	
118671	51754	format	
118672	51755	content	qew
118673	51755	format	
115386	50150	content	Przekształcenia między postaciami wymagają znajomości odpowiednich technik algebraicznych. Przejście z postaci ogólnej do kanonicznej odbywa się przez uzupełnienie do kwadratu, natomiast do postaci iloczynowej przez rozłożenie na czynniki.
115387	50150	format	
115388	50151	content	Uzupełnianie do kwadratu to technika polegająca na przekształceniu wyrażenia kwadratowego w sumę lub różnicę kwadratu dwumianu i liczby. Dla wyrażenia ax kwadrat plus bx plus c wydzielamy a przed nawias i uzupełniamy wyrażenie w nawiasie do kwadratu dwumianu.
115389	50151	format	
118350	51632	content	Funkcja kwadratowa to jedna z najważniejszych funkcji w matematyce, która ma szerokie zastosowanie zarówno w teorii jak i praktyce. Definicja funkcji kwadratowej brzmi następująco: funkcją kwadratową nazywamy funkcję postaci f(x) równa się a x do kwadratu plus b x plus c, gdzie a, b, c to liczby rzeczywiste, przy czym a różne od zera.
118351	51632	format	
118352	51633	content	Parametr a nazywamy współczynnikiem kierunkowym przy x kwadrat i determinuje on kształt paraboli. Gdy a jest większe od zera, parabola ma ramiona skierowane do góry, gdy a jest mniejsze od zera, ramiona są skierowane w dół. Parametr b wpływa na położenie wierzchołka paraboli względem osi y, natomiast parametr c określa punkt przecięcia paraboli z osią y.
118353	51633	format	
118354	51634	content	Dziedziną funkcji kwadratowej jest zbiór wszystkich liczb rzeczywistych, co oznaczamy symbolem R. Zbiór wartości funkcji kwadratowej zależy od znaku współczynnika a. Dla a większego od zera zbiorem wartości jest przedział od wartości w wierzchołku do plus nieskończoności, dla a mniejszego od zera jest to przedział od minus nieskończoności do wartości w wierzchołku.
118355	51634	format	
118356	51635	content	Wykresem funkcji kwadratowej jest parabola, która jest krzywą drugiego stopnia. Parabola ma charakterystyczną właściwość symetrii względem prostej pionowej przechodzącej przez wierzchołek, którą nazywamy osią symetrii paraboli.
118357	51635	format	
118358	51636	content	Wierzchołek paraboli to punkt, w którym funkcja osiąga wartość ekstremalną - maksimum dla a mniejszego od zera lub minimum dla a większego od zera. Współrzędne wierzchołka można obliczyć ze wzorów: x wierzchołka równa się minus b przez dwa a, y wierzchołka równa się minus delta przez cztery a, gdzie delta to dyskryminanta równa b kwadrat minus cztery a c.
118359	51636	format	
\.


--
-- TOC entry 5364 (class 0 OID 98349)
-- Dependencies: 224
-- Data for Name: chapter_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapter_blocks (id, chapter_id, type, content, sort_order, created_at, updated_at) FROM stdin;
52	29	heading	\N	0	2025-04-10 09:48:27.685	2025-04-10 09:48:27.685
53	29	text	\N	1	2025-04-10 09:48:27.691	2025-04-10 09:48:27.691
141	28	text	\N	0	2025-04-10 10:21:35.269	2025-04-10 10:21:35.269
142	28	heading	\N	1	2025-04-10 10:21:35.272	2025-04-10 10:21:35.272
143	28	text	\N	2	2025-04-10 10:21:35.274	2025-04-10 10:21:35.274
144	28	text	\N	3	2025-04-10 10:21:35.276	2025-04-10 10:21:35.276
145	28	heading	\N	4	2025-04-10 10:21:35.279	2025-04-10 10:21:35.279
53520	31	text	\N	0	2025-06-10 08:04:44.817	2025-06-10 08:04:44.817
53521	31	text	\N	1	2025-06-10 08:04:44.833	2025-06-10 08:04:44.833
53522	31	code	\N	2	2025-06-10 08:04:44.834	2025-06-10 08:04:44.834
53523	31	video	\N	3	2025-06-10 08:04:44.836	2025-06-10 08:04:44.836
53524	31	image	\N	4	2025-06-10 08:04:44.839	2025-06-10 08:04:44.839
53525	31	list	\N	5	2025-06-10 08:04:44.841	2025-06-10 08:04:44.841
53526	31	text	\N	6	2025-06-10 08:04:44.842	2025-06-10 08:04:44.842
53527	31	text	\N	7	2025-06-10 08:04:44.845	2025-06-10 08:04:44.845
50134	47	text	\N	0	2025-06-07 08:34:18.236	2025-06-07 08:34:18.236
50135	47	text	\N	1	2025-06-07 08:34:18.239	2025-06-07 08:34:18.239
50136	47	text	\N	2	2025-06-07 08:34:18.243	2025-06-07 08:34:18.243
50137	47	text	\N	3	2025-06-07 08:34:18.247	2025-06-07 08:34:18.247
50138	47	text	\N	4	2025-06-07 08:34:18.25	2025-06-07 08:34:18.25
50139	47	text	\N	5	2025-06-07 08:34:18.254	2025-06-07 08:34:18.254
50140	47	text	\N	6	2025-06-07 08:34:18.257	2025-06-07 08:34:18.257
51753	38	text	\N	0	2025-06-09 20:09:35.439	2025-06-09 20:09:35.439
50146	46	text	\N	0	2025-06-08 16:07:58.838	2025-06-08 16:07:58.838
50147	46	text	\N	1	2025-06-08 16:07:58.86	2025-06-08 16:07:58.86
50148	46	text	\N	2	2025-06-08 16:07:58.863	2025-06-08 16:07:58.863
50149	46	text	\N	3	2025-06-08 16:07:58.866	2025-06-08 16:07:58.866
50150	46	text	\N	4	2025-06-08 16:07:58.868	2025-06-08 16:07:58.868
50151	46	text	\N	5	2025-06-08 16:07:58.872	2025-06-08 16:07:58.872
51754	38	text	\N	1	2025-06-09 20:09:35.441	2025-06-09 20:09:35.441
51755	38	text	\N	2	2025-06-09 20:09:35.443	2025-06-09 20:09:35.443
51632	45	text	\N	0	2025-06-08 20:51:48.449	2025-06-08 20:51:48.449
51633	45	text	\N	1	2025-06-08 20:51:48.45	2025-06-08 20:51:48.45
51634	45	text	\N	2	2025-06-08 20:51:48.453	2025-06-08 20:51:48.453
51635	45	text	\N	3	2025-06-08 20:51:48.455	2025-06-08 20:51:48.455
51636	45	text	\N	4	2025-06-08 20:51:48.456	2025-06-08 20:51:48.456
\.


--
-- TOC entry 5366 (class 0 OID 98358)
-- Dependencies: 226
-- Data for Name: chapters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapters (id, course_id, title, wysiwyg_code, created_at, updated_at) FROM stdin;
29	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:48:27.677	2025-04-10 09:48:27.696
27	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:41:00.426	2025-04-10 09:41:00.426
28	4	Qwerty	\N	2025-04-10 09:47:01.831	2025-04-10 10:21:35.281
47	33	Równania kwadratowe i ich rozwiązywanie	\N	2025-06-07 08:33:49.715	2025-06-07 08:34:18.26
46	33	Postacie funkcji kwadratowej	\N	2025-06-07 08:33:08.425	2025-06-08 16:07:58.875
45	33	Definicja i podstawowe właściwości funkcji kwadratowej	\N	2025-06-07 08:32:23.726	2025-06-08 20:51:48.458
31	1	Lorem Ipsum	\N	2025-04-10 14:21:23.339	2025-06-10 08:04:44.847
38	1	Rozdział 3	\N	2025-04-23 09:45:37.978	2025-06-09 20:09:35.445
\.


--
-- TOC entry 5368 (class 0 OID 98366)
-- Dependencies: 228
-- Data for Name: course_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_answers (id, content, user_id, question_id, is_accepted, created_at, updated_at) FROM stdin;
1	W JavaScript najlepszą metodą do dodawania elementu na końcu tablicy jest `push()`. Przykład użycia: `array.push(newElement)`. Metoda ta zmienia długość oryginalnej tablicy i zwraca nową długość. Natomiast metoda `unshift()` dodaje element na początku tablicy.	6	3	f	2025-05-15 17:44:01.164776	2025-05-15 17:44:27.380992
2	fdsda	6	6	f	2025-05-15 22:36:22.490479	2025-05-15 22:36:22.490479
3	,m,km	6	6	f	2025-05-15 22:36:36.478577	2025-05-15 22:36:36.478577
4	asd	6	8	f	2025-05-15 23:18:29.833715	2025-05-15 23:18:29.833715
5	asd	6	8	f	2025-05-15 23:18:32.438479	2025-05-15 23:18:32.438479
6	asd	6	8	f	2025-05-15 23:24:19.501774	2025-05-15 23:24:19.501774
7	a	6	8	f	2025-05-15 23:34:47.148054	2025-05-15 23:34:47.148054
8	b	6	8	f	2025-05-15 23:34:48.760468	2025-05-15 23:34:48.760468
9	c	6	8	f	2025-05-15 23:34:49.976167	2025-05-15 23:34:49.976167
10	d	6	8	f	2025-05-15 23:34:51.277616	2025-05-15 23:34:51.277616
11	e	6	8	f	2025-05-15 23:34:52.584765	2025-05-15 23:34:52.584765
12	aasd	6	8	f	2025-05-15 23:37:38.757726	2025-05-15 23:37:38.757726
13	asdads	6	8	f	2025-05-15 23:37:41.981417	2025-05-15 23:37:41.981417
14	asdasd	6	8	f	2025-05-15 23:37:43.426767	2025-05-15 23:37:43.426767
15	zxczxc	6	8	f	2025-05-15 23:37:46.780896	2025-05-15 23:37:46.780896
16	Lorem Ipsum es simplemente el texto de relleno de las imprentas y archivos de texto. Lorem Ipsum ha sido el texto de relleno estándar de las industrias desde el año 1500, cuando un impresor (N. del T. persona que se dedica a la imprenta) desconocido usó una galería de textos y los mezcló de tal manera que logró hacer un libro de textos especimen. No sólo sobrevivió 500 años, sino que tambien ingresó como texto de relleno en documentos electrónicos, quedando esencialmente igual al original. Fue popularizado en los 60s con la creación de las hojas "Letraset", las cuales contenian pasajes de Lorem Ipsum, y más recientemente con software de autoedición, como por ejemplo Aldus PageMaker, el cual incluye versiones de Lorem Ipsum.\n\n	6	8	f	2025-05-15 23:40:31.422419	2025-05-15 23:40:31.422419
17	qweqwe	6	8	f	2025-05-15 23:40:40.963399	2025-05-15 23:40:40.963399
18	asd	6	8	f	2025-05-15 23:40:49.332149	2025-05-15 23:40:49.332149
20	j	6	8	f	2025-05-16 10:14:18.274454	2025-05-16 10:14:18.274454
21	qweqweqweqweqw	6	8	f	2025-05-16 13:49:22.793199	2025-05-16 13:49:22.793199
24	asd	6	8	f	2025-05-16 14:30:20.295805	2025-05-16 14:30:20.295805
25	asd	6	8	f	2025-05-16 14:35:56.208825	2025-05-16 14:35:56.208825
26	asd	6	8	f	2025-05-16 14:36:02.499543	2025-05-16 14:36:02.499543
27	asdasdasdsa	6	8	f	2025-05-16 14:36:14.741663	2025-05-16 14:36:14.741663
31	Na kogo będziesz głosował w wyborach \n	6	8	f	2025-05-16 14:37:32.276553	2025-05-16 14:37:32.276553
36	asd	6	8	f	2025-05-16 14:50:23.901837	2025-05-16 14:50:23.901837
37	asd	6	8	f	2025-05-16 14:52:06.127399	2025-05-16 14:52:06.127399
38	asd	6	8	f	2025-05-16 14:55:05.905635	2025-05-16 14:55:05.905635
39	To jest odpowiedz testowa	6	8	f	2025-05-16 14:55:39.263283	2025-05-16 14:55:39.263283
40	testowa wiadomosc	6	8	f	2025-05-16 14:56:34.095311	2025-05-16 14:56:34.095311
42	asdasdsadasd	6	8	f	2025-05-16 15:13:21.959816	2025-05-16 15:13:21.959816
43	asdsadasds	6	8	f	2025-05-16 15:13:25.223181	2025-05-16 15:13:25.223181
\.


--
-- TOC entry 5371 (class 0 OID 98380)
-- Dependencies: 232
-- Data for Name: course_logs_y202505; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202505 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
1	18	\N	COURSE_CREATED	\N	asd	asd	Utworzenie kursu	2025-05-14 22:44:16.001967
12	\N	\N	COURSE_DELETED	\N	\N	asd	Course ID 18 deleted	2025-05-17 15:52:08.487374
13	\N	\N	COURSE_DELETED	\N	\N	asd	Course ID 18 deleted	2025-05-17 15:52:58.810845
14	\N	\N	COURSE_DELETED	\N	\N	asd	Course ID 18 deleted	2025-05-17 15:53:33.673584
15	\N	\N	COURSE_DELETED	\N	\N	asd	Course ID 18 deleted	2025-05-17 15:54:17.094603
16	1	\N	COURSE_UPDATED	\N	\N	kurs pokazowy	\N	2025-05-17 16:02:05.259722
18	\N	\N	COURSE_DELETED	\N	\N	asd	Course ID 20 deleted	2025-05-17 16:04:53.621273
29	\N	\N	COURSE_DELETED	\N	\N	Testowy kurs 	Course ID 22 deleted	2025-05-17 16:24:57.327828
33	\N	\N	COURSE_DELETED	\N	\N	qwe	Course ID 24 deleted	2025-05-17 16:35:54.263701
37	\N	\N	COURSE_DELETED	\N	\N	Testowy kurs edycja	Course ID 25 deleted	2025-05-17 16:40:08.746176
38	26	\N	COURSE_CREATED	\N	\N	Nowy kurs	Kurs utworzony	2025-05-17 16:55:55.636423
42	26	\N	COURSE_UPDATED	asd	asd qwe	asd qwe	Zmiana tytułu z "asd" na "asd qwe"	2025-05-17 17:00:51.648953
44	1	\N	COURSE_UPDATED	kurs pokazowyq	kurs pokazowy	kurs pokazowy	Zmiana tytułu z "kurs pokazowyq" na "kurs pokazowy"	2025-05-28 11:58:09.158979
46	\N	\N	COURSE_DELETED	\N	\N	etestasdasdqqqqqqqq	Course ID 23 deleted	2025-05-28 11:58:34.414252
50	\N	\N	COURSE_DELETED	\N	\N	Siemanko2115123	Course ID 29 deleted	2025-05-28 12:15:38.581808
48	\N	\N	COURSE_CREATED	\N	\N	Siemanko2115	Kurs utworzony	2025-05-28 12:09:43.501318
49	\N	\N	COURSE_UPDATED	Siemanko2115	Siemanko2115123	Siemanko2115123	Zmiana tytułu z "Siemanko2115" na "Siemanko2115123"	2025-05-28 12:15:35.019116
51	\N	\N	COURSE_DELETED	\N	\N	asdasdsa	Course ID 28 deleted	2025-05-28 12:25:10.418976
47	\N	\N	COURSE_CREATED	\N	\N	asdasdsa	Kurs utworzony	2025-05-28 12:09:01.669378
52	\N	\N	COURSE_DELETED	\N	\N	asd qwe	Course ID 26 deleted	2025-05-28 13:37:31.401815
53	\N	\N	COURSE_DELETED	\N	\N	Jakiś tam kurs	Course ID 27 deleted	2025-05-30 15:39:27.553134
\.


--
-- TOC entry 5372 (class 0 OID 98387)
-- Dependencies: 233
-- Data for Name: course_logs_y202506; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202506 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
54	4	\N	COURSE_UPDATED	\N	\N	Januszex	Kurs zaktualizowany	2025-06-05 15:26:30.661775
55	1	\N	COURSE_UPDATED	kurs pokazowy	Kurs pokazowy 	Kurs pokazowy 	Zmiana tytułu z "kurs pokazowy" na "Kurs pokazowy "	2025-06-05 15:30:26.473863
56	1	\N	COURSE_UPDATED	\N	\N	Kurs pokazowy 	Kurs zaktualizowany	2025-06-05 15:34:11.269064
57	30	\N	COURSE_CREATED	\N	\N	kurs	Kurs utworzony	2025-06-05 16:56:57.255576
58	\N	\N	COURSE_DELETED	\N	\N	kurs	Course ID 30 deleted	2025-06-07 09:23:39.386384
63	31	\N	COURSE_CREATED	\N	\N	TEST	Kurs utworzony	2025-06-07 09:53:11.955102
64	\N	\N	COURSE_DELETED	\N	\N	TEST	Course ID 31 deleted	2025-06-07 09:54:19.920448
65	4	\N	COURSE_UPDATED	\N	\N	Januszex	Kurs zaktualizowany	2025-06-07 09:58:13.82529
66	1	\N	COURSE_UPDATED	\N	\N	Kurs pokazowy 	Kurs zaktualizowany	2025-06-07 09:58:58.675342
67	32	\N	COURSE_CREATED	\N	\N	Funkcje kwadratowe - podstawy	Kurs utworzony	2025-06-07 10:03:27.870112
68	\N	\N	COURSE_DELETED	\N	\N	Funkcje kwadratowe - podstawy	Course ID 32 deleted	2025-06-07 10:31:33.328287
69	33	\N	COURSE_CREATED	\N	\N	Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań	Kurs utworzony	2025-06-07 10:32:16.685248
70	33	\N	COURSE_UPDATED	\N	\N	Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań	Kurs zaktualizowany	2025-06-07 18:45:52.964984
71	33	\N	COURSE_UPDATED	Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań	Funkcje Kwadratowe - Kompletny Przewodnik	Funkcje Kwadratowe - Kompletny Przewodnik	Zmiana tytułu z "Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań" na "Funkcje Kwadratowe - Kompletny Przewodnik"	2025-06-08 17:43:48.357369
72	4	\N	COURSE_UPDATED	\N	\N	Januszex	Kurs zaktualizowany	2025-06-08 22:31:29.983996
73	1	\N	COURSE_UPDATED	\N	\N	Kurs pokazowy 	Kurs zaktualizowany	2025-06-08 22:44:04.152974
74	34	\N	COURSE_CREATED	\N	\N	Przykładowy kurs	Kurs utworzony	2025-06-09 00:21:22.665525
75	\N	\N	COURSE_DELETED	\N	\N	Przykładowy kurs	Course ID 34 deleted	2025-06-09 17:54:03.79632
76	35	\N	COURSE_CREATED	\N	\N	asdasd	Kurs utworzony	2025-06-10 09:36:21.149907
77	\N	\N	COURSE_DELETED	\N	\N	asdasd	Course ID 35 deleted	2025-06-10 09:36:43.197107
79	4	\N	COURSE_UPDATED	\N	\N	Januszex	Kurs zaktualizowany	2025-06-10 10:01:54.147865
\.


--
-- TOC entry 5373 (class 0 OID 98394)
-- Dependencies: 234
-- Data for Name: course_logs_y202507; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202507 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
\.


--
-- TOC entry 5374 (class 0 OID 98401)
-- Dependencies: 235
-- Data for Name: course_logs_y202508; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202508 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
\.


--
-- TOC entry 5375 (class 0 OID 98408)
-- Dependencies: 236
-- Data for Name: course_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_notes (id, title, content, user_id, course_id, file_path, file_name, created_at, updated_at) FROM stdin;
1	Moja notatka	Cześć wrzucam wam moje notatki z baz danych 	6	1	C:/Users/kgruc/OneDrive/Pulpit/CourseFlow-Backend/uploads/document-1748703452619-807210381.png	p2.png	2025-05-31 16:57:32.667172	2025-05-31 16:57:32.667172
2	a	a	6	4	C:/Users/kgruc/OneDrive/Pulpit/CourseFlow-Backend/uploads/document-1748703481542-339716746.txt	Partycje baza polecenia.txt	2025-05-31 16:58:01.587578	2025-05-31 16:58:01.587578
3	fsdfsd	dasfds	6	1	C:/Users/kgruc/OneDrive/Pulpit/CourseFlow-Backend/uploads/document-1748884623930-539152158.jpg	lfndtoirttvx.jpg	2025-06-02 19:17:03.943712	2025-06-02 19:17:03.943712
4	test	test 	82	4	C:/Users/kgruc/OneDrive/Pulpit/CourseFlow-Backend/uploads/document-1749131078097-32163649.jpg	rudy.jpg	2025-06-05 15:44:38.178766	2025-06-05 15:44:38.178766
\.


--
-- TOC entry 5377 (class 0 OID 98416)
-- Dependencies: 238
-- Data for Name: course_questions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_questions (id, title, content, user_id, course_id, created_at, updated_at, views) FROM stdin;
2	Jak działa mechanizm dziedziczenia w JavaScript?	Czy ktoś może wyjaśnić, jak działa dziedziczenie prototypowe w JavaScript i czym różni się od dziedziczenia klasowego znanego z innych języków?	6	\N	2025-05-15 15:23:05.054	2025-05-15 15:23:05.054	0
5	Dlaczego niebo jest niebieskie	Chce wiedzieć dlaczego niebo jest niebieskie	6	1	2025-05-15 17:43:54.227	2025-05-15 17:43:54.227	0
3	Jak dodać nowy element do tablicy w JavaScript?	Próbuję dodać nowy element na końcu tablicy w JavaScript. Jaką metodę powinienem użyć? Czy istnieje różnica między metodami push i unshift?	6	4	2025-05-15 15:43:24.082	2025-05-15 15:43:24.082	3
6	asd	asd	6	1	2025-05-15 20:07:54.616	2025-05-15 20:07:54.616	12
11	Siemanko mam pytanie	asdasdasdsadsa	6	\N	2025-05-19 08:23:24.149	2025-05-30 10:20:57.644597	13
7	qwe	qwe	6	1	2025-05-15 20:10:02.795	2025-05-15 20:10:02.795	14
4	asd	asd	6	\N	2025-05-15 16:46:33.189	2025-05-15 16:46:33.189	2
8	Siema	Siema	6	\N	2025-05-15 21:05:18.7	2025-05-15 21:05:18.7	146
10	Siema mam pytanie	to jest moje pytanie	6	\N	2025-05-18 14:58:58.961	2025-05-18 14:58:58.961	17
\.


--
-- TOC entry 5379 (class 0 OID 98425)
-- Dependencies: 240
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.courses (id, user_id, title, short_description, course_image, category, is_published, created_at, updated_at) FROM stdin;
33	6	Funkcje Kwadratowe - Kompletny Przewodnik	Szczegółowy kurs poświęcony funkcjom kwadratowych obejmujący wszystkie aspekty teorii i praktyki. Poznasz definicję funkcji kwadratowej, metody rozwiązywania równań, analizę wykresu paraboli, przekształcenia geometryczne.	image-1749314752952-207104451.jpg	matematyka	f	2025-06-07 08:32:16.685	2025-06-08 15:43:48.351
1	6	Kurs pokazowy 	Tu jest kurs pokazowy 	image-1749415444100-187904830.jpg	programowanie	f	2025-04-06 18:29:30.271	2025-06-08 20:44:04.151
4	6	Januszex	Jak zostać januszem biznesu. Kurs skrócony. 	image-1749542514072-849844830.jpg	biznes	f	2025-04-08 11:52:17.883	2025-06-10 08:01:54.14
\.


--
-- TOC entry 5381 (class 0 OID 98434)
-- Dependencies: 242
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, title, message, type, related_entity_id, created_at, is_read) FROM stdin;
690	6	Nowy kurs dostępny!	Nowy kurs "asd" jest już dostępny na platformie.	NEW_COURSE	18	2025-05-14 22:44:16.001967+02	t
3	6	Nowy kurs dostępny!	Nowy kurs "Nowy kurs testowy" jest już dostępny na platformie.	NEW_COURSE	8	2025-05-09 13:21:38.419865+02	t
780	6	Nowy kurs dostępny!	Nowy kurs "Jakiś tam kurs" jest już dostępny na platformie.	NEW_COURSE	27	2025-05-19 23:17:13.84999+02	t
32	6	Nowy kurs dostępny!	Nowy kurs "asdy" jest już dostępny na platformie.	NEW_COURSE	9	2025-05-09 13:22:27.214202+02	t
61	6	Nowy kurs dostępny!	Nowy kurs "qweqweqwe" jest już dostępny na platformie.	NEW_COURSE	10	2025-05-09 14:12:40.374794+02	t
787	6	Nowy kurs dostępny!	Nowy kurs "asdasdsa" jest już dostępny na platformie.	NEW_COURSE	28	2025-05-28 12:09:01.669378+02	t
792	6	Nowy kurs dostępny!	Nowy kurs "Siemanko2115" jest już dostępny na platformie.	NEW_COURSE	29	2025-05-28 12:09:43.501318+02	t
90	6	Ważna informacja od administratora	Dzisiaj wieczorem system będzie niedostępny z powodu aktualizacji. Planowany czas niedostępności: 22:00-23:00.	ADMIN_ANNOUNCEMENT	\N	2025-05-09 15:51:38.999+02	t
120	6	Powiadomienie testowe	To jest treść testowego powiadomienia 	ADMIN_ANNOUNCEMENT	\N	2025-05-09 15:57:15.772+02	t
150	6	Dziś jest wtorek 	No dziś jest wtorek 	ADMIN_ANNOUNCEMENT	\N	2025-05-09 16:38:26.038+02	t
180	6	Nowy kurs dostępny!	Nowy kurs "asd" jest już dostępny na platformie.	NEW_COURSE	11	2025-05-09 17:06:38.478321+02	t
493	6	Nowy kurs dostępny!	Nowy kurs "Testowy" jest już dostępny na platformie.	NEW_COURSE	12	2025-05-12 19:13:06.798537+02	t
519	6	Nowy kurs dostępny!	Nowy kurs "asd" jest już dostępny na platformie.	NEW_COURSE	13	2025-05-13 14:11:59.799762+02	t
546	6	test	test	ADMIN_ANNOUNCEMENT	\N	2025-05-13 14:12:12.932+02	t
571	6	Witaj w CourseFlow!	Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!	WELCOME	\N	2025-05-14 11:23:00.821+02	t
598	6	Nowy kurs dostępny!	Nowy kurs "Kurs_do_testowania_logów" jest już dostępny na platformie.	NEW_COURSE	14	2025-05-14 12:16:24.25602+02	t
625	6	Nowy kurs dostępny!	Nowy kurs "aha" jest już dostępny na platformie.	NEW_COURSE	15	2025-05-14 12:29:06.288037+02	t
652	6	Nowy kurs dostępny!	Nowy kurs "Januszex2" jest już dostępny na platformie.	NEW_COURSE	16	2025-05-14 12:34:42.032978+02	t
679	6	Nowy kurs dostępny!	Nowy kurs "Kurs_do_testowania" jest już dostępny na platformie.	NEW_COURSE	17	2025-05-14 12:46:58.148448+02	t
702	6	Nowy kurs dostępny!	Nowy kurs "asd" jest już dostępny na platformie.	NEW_COURSE	20	2025-05-17 16:02:16.42672+02	t
714	6	Nowy kurs dostępny!	Nowy kurs "asdgggggg" jest już dostępny na platformie.	NEW_COURSE	21	2025-05-17 16:24:07.679654+02	t
726	6	Nowy kurs dostępny!	Nowy kurs "Testowy kurs " jest już dostępny na platformie.	NEW_COURSE	22	2025-05-17 16:24:45.688048+02	t
738	6	Nowy kurs dostępny!	Nowy kurs "etest" jest już dostępny na platformie.	NEW_COURSE	23	2025-05-17 16:30:18.126642+02	t
750	6	Nowy kurs dostępny!	Nowy kurs "qwe" jest już dostępny na platformie.	NEW_COURSE	24	2025-05-17 16:35:48.204974+02	t
762	6	Nowy kurs dostępny!	Nowy kurs "Testowy kurs" jest już dostępny na platformie.	NEW_COURSE	25	2025-05-17 16:38:52.20272+02	t
774	6	Nowy kurs dostępny!	Nowy kurs "Nowy kurs" jest już dostępny na platformie.	NEW_COURSE	26	2025-05-17 16:55:55.636423+02	t
801	6	asd	asd	ADMIN_ANNOUNCEMENT	\N	2025-05-31 13:59:08.022+02	t
805	82	Witaj w CourseFlow!	Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!	WELCOME	\N	2025-06-05 15:37:58.664+02	t
807	82	Nowy kurs dostępny!	Nowy kurs "kurs" jest już dostępny na platformie.	NEW_COURSE	30	2025-06-05 16:56:57.255576+02	f
808	6	Nowy kurs dostępny!	Nowy kurs "kurs" jest już dostępny na platformie.	NEW_COURSE	30	2025-06-05 16:56:57.255576+02	t
810	82	Nowy kurs dostępny!	Nowy kurs "TEST" jest już dostępny na platformie.	NEW_COURSE	31	2025-06-07 09:53:11.955102+02	f
814	82	Nowy kurs dostępny!	Nowy kurs "Funkcje kwadratowe - podstawy" jest już dostępny na platformie.	NEW_COURSE	32	2025-06-07 10:03:27.870112+02	f
818	82	Nowy kurs dostępny!	Nowy kurs "Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań" jest już dostępny na platformie.	NEW_COURSE	33	2025-06-07 10:32:16.685248+02	f
813	6	Nowy kurs dostępny!	Nowy kurs "TEST" jest już dostępny na platformie.	NEW_COURSE	31	2025-06-07 09:53:11.955102+02	t
817	6	Nowy kurs dostępny!	Nowy kurs "Funkcje kwadratowe - podstawy" jest już dostępny na platformie.	NEW_COURSE	32	2025-06-07 10:03:27.870112+02	t
821	6	Nowy kurs dostępny!	Nowy kurs "Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań" jest już dostępny na platformie.	NEW_COURSE	33	2025-06-07 10:32:16.685248+02	t
803	79	asd	asd	ADMIN_ANNOUNCEMENT	\N	2025-05-31 13:59:08.022+02	t
806	79	Nowy kurs dostępny!	Nowy kurs "kurs" jest już dostępny na platformie.	NEW_COURSE	30	2025-06-05 16:56:57.255576+02	t
811	79	Nowy kurs dostępny!	Nowy kurs "TEST" jest już dostępny na platformie.	NEW_COURSE	31	2025-06-07 09:53:11.955102+02	t
815	79	Nowy kurs dostępny!	Nowy kurs "Funkcje kwadratowe - podstawy" jest już dostępny na platformie.	NEW_COURSE	32	2025-06-07 10:03:27.870112+02	t
819	79	Nowy kurs dostępny!	Nowy kurs "Funkcje Kwadratowe - Kompletny Przewodnik od Podstaw do Zastosowań" jest już dostępny na platformie.	NEW_COURSE	33	2025-06-07 10:32:16.685248+02	t
822	79	Witaj w CourseFlow!	Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!	WELCOME	\N	2025-06-08 17:20:14.276+02	t
823	82	Nowy kurs dostępny!	Nowy kurs "Przykładowy kurs" jest już dostępny na platformie.	NEW_COURSE	34	2025-06-09 00:21:22.665525+02	f
825	79	Nowy kurs dostępny!	Nowy kurs "Przykładowy kurs" jest już dostępny na platformie.	NEW_COURSE	34	2025-06-09 00:21:22.665525+02	f
824	6	Nowy kurs dostępny!	Nowy kurs "Przykładowy kurs" jest już dostępny na platformie.	NEW_COURSE	34	2025-06-09 00:21:22.665525+02	t
827	87	Witaj w CourseFlow!	Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!	WELCOME	\N	2025-06-10 09:34:56.907+02	f
828	85	Nowy kurs dostępny!	Nowy kurs "asdasd" jest już dostępny na platformie.	NEW_COURSE	35	2025-06-10 09:36:21.149907+02	f
829	79	Nowy kurs dostępny!	Nowy kurs "asdasd" jest już dostępny na platformie.	NEW_COURSE	35	2025-06-10 09:36:21.149907+02	f
830	82	Nowy kurs dostępny!	Nowy kurs "asdasd" jest już dostępny na platformie.	NEW_COURSE	35	2025-06-10 09:36:21.149907+02	f
831	87	Nowy kurs dostępny!	Nowy kurs "asdasd" jest już dostępny na platformie.	NEW_COURSE	35	2025-06-10 09:36:21.149907+02	f
832	6	Nowy kurs dostępny!	Nowy kurs "asdasd" jest już dostępny na platformie.	NEW_COURSE	35	2025-06-10 09:36:21.149907+02	t
\.


--
-- TOC entry 5383 (class 0 OID 98442)
-- Dependencies: 244
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.permissions (id, name, description, created_at, updated_at) FROM stdin;
4	PANEL_SHOW_USERS_LIST	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
6	PANEL_EDIT_USERS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
7	PANEL_CREATE_ROLE	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
8	PANEL_SHOW_TESTS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
10	PANEL_SHOW_ADMIN_PANEL	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
11	PANEL_SHOW_USERS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
1	PANEL_SETTINGS_PARTITION	\N	2025-05-31 09:02:17.008898	2025-05-31 09:02:17.008898
2	PANEL_SHOW_COURSES_LOGS	\N	2025-05-31 09:02:46.907074	2025-05-31 09:02:46.907074
3	PANEL_SHOW_USER_LOGS	\N	2025-05-31 09:02:55.173766	2025-05-31 09:02:55.173766
5	PANEL_CREATE_COURSES	\N	2025-05-31 09:03:31.288093	2025-05-31 09:03:31.288093
12	PANEL_MODIFY_COURSES	\N	2025-05-31 09:04:33.954781	2025-05-31 09:04:33.954781
13	PANEL_CREATE_NOTIFICATIONS	\N	2025-05-31 09:04:42.427436	2025-05-31 09:04:42.427436
\.


--
-- TOC entry 5385 (class 0 OID 98450)
-- Dependencies: 246
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.role_permissions (role_id, permission_id, created_at, updated_at) FROM stdin;
1	4	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	6	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	7	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	8	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	10	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	11	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	1	2025-05-31 09:09:24.317312	2025-05-31 09:09:24.317312
1	2	2025-05-31 09:09:27.453145	2025-05-31 09:09:27.453145
1	3	2025-05-31 09:09:29.553673	2025-05-31 09:09:29.553673
1	5	2025-05-31 09:09:34.468237	2025-05-31 09:09:34.468237
1	12	2025-05-31 09:09:52.138787	2025-05-31 09:09:52.138787
1	13	2025-05-31 09:09:54.40098	2025-05-31 09:09:54.40098
7	10	2025-05-31 14:41:56.280219	2025-05-31 14:41:56.280219
7	11	2025-05-31 14:41:56.35689	2025-05-31 14:41:56.35689
7	4	2025-05-31 14:41:56.359529	2025-05-31 14:41:56.359529
21	8	2025-06-09 00:05:11.540636	2025-06-09 00:05:11.540636
21	3	2025-06-09 00:05:11.615698	2025-06-09 00:05:11.615698
21	10	2025-06-09 00:05:11.621577	2025-06-09 00:05:11.621577
21	11	2025-06-09 00:05:11.630428	2025-06-09 00:05:11.630428
21	2	2025-06-09 00:05:11.635875	2025-06-09 00:05:11.635875
22	10	2025-06-09 19:55:33.146637	2025-06-09 19:55:33.146637
\.


--
-- TOC entry 5386 (class 0 OID 98455)
-- Dependencies: 247
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name, description, created_at, updated_at) FROM stdin;
2	user	\N	2025-04-06 20:18:11.248218	2025-04-06 20:18:11.248218
1	admin	\N	2025-04-06 20:20:53.067592	2025-04-06 20:20:53.067592
7	Mini Admin	\N	2025-05-11 21:33:17.667275	2025-05-11 21:33:17.667275
21	test	\N	2025-06-09 00:04:59.353117	2025-06-09 00:04:59.353117
22	qwe	\N	2025-06-09 19:55:33.135731	2025-06-09 19:55:33.135731
\.


--
-- TOC entry 5388 (class 0 OID 98463)
-- Dependencies: 249
-- Data for Name: test_block_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_block_answers (id, block_id, answer_text, is_correct, feedback, sort_order) FROM stdin;
73	19	4	t		1
74	19	5	f		2
75	19	6	f		3
76	19	7	f		4
77	20	3	f		1
78	20	4	f		2
79	20	10	t		3
80	20	11	f		4
81	21	29	f		1
82	21	30	f		2
83	21	31	t		3
84	21	32	f		4
85	22	Barcelona	t		1
86	22	Legia Warszawa	f		2
87	22	Real Madryt (xD)	f		3
88	22	Juventus 	f		4
89	23	seria 3 e90	t		1
95	26	BMW 	t		1
96	26	Kia	t		2
97	26	Audi	t		3
98	26	Mercedes 	t		4
99	27	Jeden	t		1
100	27	Dwa	t		2
101	27	Trzy	t		3
49	13	Niemiec	t		1
50	13	Japonii	f		2
51	13	Francji	f		3
52	13	Polski	f		4
57	15	Ponieważ ma najlepsze osiągi	f		1
58	15	Ponieważ ma najnowocześniejszą technologie	f		2
59	15	Ponieważ ma najlepszy wygląd	f		3
60	15	Wszystkie odpowiedzi są poprawne 	t		4
102	28	Prawda	t		1
103	28	Fałsz	f		2
128	36	f(x) = ax + b	f		1
129	36	f(x) = ax² + bx + c, gdzie a ≠ 0	t		2
130	36	f(x) = a/x + b	f		3
131	36	f(x) = a·bˣ	f		4
132	37	Dziedziną jest zbiór liczb rzeczywistych	t		1
133	37	Wykresem jest parabola	t		2
134	37	Ma zawsze dwa miejsca zerowe ✗ (może mieć 0, 1 lub 2)	f		3
135	37	Współczynnik a określa kierunek ramion paraboli	t		4
136	38	Parametr a	t		1
137	38	Parametr b	t		2
138	38	Parametr c	t		3
139	38	Delta (Δ)	t		4
140	39	2	t		1
141	40	Prawda	t		1
142	40	Fałsz	f		2
143	41	Postać ogólna	f		1
144	41	Postać kanoniczna	t		2
145	41	Postać iloczynowa	f		3
146	41	Wszystkie postacie	f		4
147	42	Miejsca zerowe funkcji	t		1
148	42	Wierzchołek paraboli	f		2
149	42	Punkt przecięcia z osią y	f		3
150	42	Współczynnik kierunkowy a	t		4
151	43	f(x) = ax² + bx + c	t		1
152	43	f(x) = a(x-p)² + q	t		2
153	43	f(x) = a(x-x₁)(x-x₂)	t		3
154	43	Uzupełnienie do kwadratu	t		4
155	44	f(x) = (x - 3)² - 1	t		1
156	45	Prawda	f		1
157	45	Fałsz	t		2
158	46	Żadnego	f		1
159	46	Jedno	t		2
160	46	Dwa różne	f		3
161	46	Nieskończenie wiele	f		4
162	47	Δ > 0 	t		1
163	47	Δ = 0 	t		2
164	47	Δ < 0 	t		3
165	47	Wzory Vieta	t		4
166	48	25	t		1
167	49	Prawda	t		1
168	49	Fałsz	f		2
169	50	Postać ogólna f(x) = ax² + bx + c 	f		1
170	50	Postać kanoniczna f(x) = a(x-p)² + q	f		2
171	50	Postać iloczynowa f(x) = a(x-x₁)(x-x₂)	t		3
172	50	Wszystkie postacie są równie przydatne	f		4
173	51	Ramiona paraboli skierowane w dół	t		1
174	51	Wierzchołek w punkcie (2, 7)	t		2
175	51	Funkcja ma maksimum globalne	t		3
176	51	Przecięcie z osią y w punkcie (0, -5)	t		4
177	52	Prawda	t		1
178	52	Fałsz	f		2
\.


--
-- TOC entry 5390 (class 0 OID 98471)
-- Dependencies: 251
-- Data for Name: test_block_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_block_attributes (id, block_id, attribute_name, attribute_value) FROM stdin;
\.


--
-- TOC entry 5392 (class 0 OID 98477)
-- Dependencies: 253
-- Data for Name: test_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_blocks (id, test_id, block_type, question_text, points, sort_order, created_at, updated_at) FROM stdin;
21	6	single_choice	Ile dni ma marzec	2	1	2025-05-01 06:12:03.133	2025-05-01 06:12:03.133
22	6	single_choice	W jakim klubie gra Lewandowski (Goat)	3	2	2025-05-01 06:13:01.531	2025-05-01 06:13:01.531
13	3	single_choice	Z jakiego kraju pochodzi BMW 	1	0	2025-04-29 06:57:08.448	2025-04-29 16:26:57.701
15	3	single_choice	Dlaczego BMW jest najlepszym autem na rynku	3	1	2025-04-29 07:00:03.884	2025-04-29 16:26:57.701
40	12	true_false	Jeśli a > 0, to parabola ma ramiona skierowane w górę	1	4	2025-06-07 08:38:50.313	2025-06-07 08:38:56.733
39	12	text_input	Dla funkcji f(x) = 2x² - 8x + 3, współrzędna x wierzchołka wynosi: x =	1	3	2025-06-07 08:38:27.061	2025-06-07 08:38:56.733
38	12	matching	Dopasuj parametry funkcji kwadratowej do ich znaczenia:	1	2	2025-06-07 08:37:45.646	2025-06-07 08:38:56.733
36	12	single_choice	Jaka jest postać ogólna funkcji kwadratowej?	1	0	2025-06-07 08:35:57.143	2025-06-07 08:38:56.733
37	12	multiple_choice	Które z poniższych stwierdzeń o funkcji kwadratowej są prawdziwe?	2	1	2025-06-07 08:36:40.062	2025-06-07 08:38:56.733
41	13	single_choice	Która postać funkcji kwadratowej pozwala bezpośrednio odczytać wierzchołek?	1	1	2025-06-07 08:40:24.558	2025-06-07 08:40:24.558
42	13	multiple_choice	Które informacje można bezpośrednio odczytać z postaci iloczynowej?	2	2	2025-06-07 08:41:36.845	2025-06-07 08:41:36.845
43	13	matching	Dopasuj postacie funkcji do informacji, które można z nich odczytać:	2	3	2025-06-07 08:42:28.573	2025-06-07 08:42:28.573
44	13	text_input	 Funkcja f(x) = x² - 6x + 8 w postaci kanonicznej to f(x) = (x - ___)² - ___	1	4	2025-06-07 08:43:09.107	2025-06-07 08:43:09.107
45	13	true_false	Postać iloczynowa istnieje dla każdej funkcji kwadratowej.	1	5	2025-06-07 08:43:32.712	2025-06-07 08:43:32.712
46	14	single_choice	Ile rozwiązań ma równanie kwadratowe, gdy Δ = 0?	1	1	2025-06-07 08:44:38.558	2025-06-07 08:44:38.558
47	14	matching	Dopasuj wartości dyskryminanty do liczby rozwiązań:	4	2	2025-06-07 08:45:47.606	2025-06-07 08:45:47.606
48	14	text_input	Dla równania 2x² - 7x + 3 = 0, dyskryminanta Δ = ___	2	3	2025-06-07 08:46:13.658	2025-06-07 08:46:13.658
49	14	true_false	Jeśli suma pierwiastków równania kwadratowego wynosi 4, to współczynnik b = -4a.	1	4	2025-06-07 08:46:40.441	2025-06-07 08:46:40.441
50	15	single_choice	Która postać funkcji kwadratowej najlepiej nadaje się do odczytania miejsc zerowych?	1	1	2025-06-07 08:47:49.066	2025-06-07 08:47:49.066
51	15	multiple_choice	Funkcja f(x) = -3x² + 12x - 5 ma następujące właściwości: (Zaznacz wszystkie poprawne)	3	2	2025-06-07 08:49:11.985	2025-06-07 08:49:11.985
52	15	true_false	Jeśli dyskryminanta równania kwadratowego jest liczbą ujemną, to funkcja kwadratowa nie ma miejsc zerowych.	1	3	2025-06-07 08:49:34.201	2025-06-07 08:49:34.201
19	4	single_choice	Ile to jest 2+2	1	2	2025-04-30 08:03:21.58	2025-06-09 20:22:26.303
23	4	text_input	Jak sie nazywa najlepszy model BMW 	3	1	2025-05-05 06:44:57.907	2025-06-09 20:22:26.303
20	4	single_choice	Ile to 5+5	3	0	2025-04-30 08:03:36.409	2025-06-09 20:22:26.303
27	4	matching	Dopasuj Cyfry	1	4	2025-05-06 10:03:53.123	2025-06-09 20:22:26.303
26	4	matching	Dopasuj model auta do marki 	1	3	2025-05-06 05:41:23.907	2025-06-09 20:22:26.303
28	4	true_false	Czy niebo jest niebieskie 	1	5	2025-05-12 21:19:50.954	2025-06-09 20:22:26.303
\.


--
-- TOC entry 5394 (class 0 OID 98487)
-- Dependencies: 255
-- Data for Name: tests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tests (id, chapter_id, course_id, author_id, title, description, pass_threshold, time_limit, created_at, updated_at, is_course_final) FROM stdin;
3	31	1	6	Test		60	0	2025-04-28 19:47:34.512	2025-04-28 19:47:34.512	f
4	\N	1	6	asd	ads	70	3	2025-04-29 21:22:55.778	2025-04-30 08:30:54.113	t
6	38	1	6	Rozdział 3 test		70	9	2025-05-01 06:11:33.048	2025-05-15 13:39:15.952	f
12	45	33	6	Test do Rozdziału 1		70	3	2025-06-07 08:35:11.473	2025-06-07 08:35:11.473	f
13	46	33	6	Test do Rozdziału 2		50	6	2025-06-07 08:39:42.347	2025-06-07 08:39:42.347	f
14	47	33	6	Test do Rozdziału 3		60	10	2025-06-07 08:44:01.924	2025-06-07 08:44:01.924	f
15	\N	33	6	Test dla całego kursu		50	15	2025-06-07 08:46:58.942	2025-06-07 08:46:58.942	t
\.


--
-- TOC entry 5396 (class 0 OID 98498)
-- Dependencies: 257
-- Data for Name: user_chapter; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_chapter (id, user_id, chapter_id, is_completed, last_viewed) FROM stdin;
\.


--
-- TOC entry 5398 (class 0 OID 98504)
-- Dependencies: 259
-- Data for Name: user_courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_courses (id, user_id, course_id, progress, status, created_at) FROM stdin;
5	6	1	0.00	not_started	2025-05-02 14:59:15.956
6	6	4	0.00	not_started	2025-05-04 09:09:13.752
12	82	1	0.00	not_started	2025-06-05 13:45:30.481
14	6	33	0.00	not_started	2025-06-07 08:51:18.107
\.


--
-- TOC entry 5401 (class 0 OID 98516)
-- Dependencies: 263
-- Data for Name: user_logs_y202505; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202505 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
10	USER_DELETED	\N	\N	testijvskrew@example.com	\N	2025-05-14 17:21:09.909396
11	USER_DELETED	\N	\N	testijvskrew@example.com	\N	2025-05-14 17:21:09.948408
12	USER_DELETED	\N	\N	testjcdqsdje@example.com	\N	2025-05-14 17:21:15.755257
13	USER_DELETED	\N	\N	testjcdqsdje@example.com	\N	2025-05-14 17:21:15.759965
14	USER_DELETED	\N	\N	testhwxoasbk@example.com	\N	2025-05-14 17:24:37.494218
4	ROLE_CHANGED	\N	6	user	admin	2025-05-14 16:51:50.493126
15	ROLE_CHANGED	\N	6	admin	Moderator kursów 	2025-05-14 17:24:43.906423
16	USER_DELETED	\N	\N	testxnqtinsn@example.com	\N	2025-05-14 17:24:47.489609
17	USER_DELETED	\N	\N	testrqcpquei@example.com	\N	2025-05-14 17:45:22.797024
18	USER_DELETED	\N	\N	kubanowak@interia.pl	\N	2025-05-14 17:45:34.082175
20	USER_DELETED	\N	6	a@interia.pl	\N	2025-05-14 17:48:31.290271
21	USER_DELETED	\N	\N	a@interia.pl	\N	2025-05-14 17:48:31.297222
22	USER_DELETED	\N	\N	qwe@qwe.pl	\N	2025-05-14 17:50:43.235021
23	USER_DELETED	\N	\N	testeeebczhi@example.com	\N	2025-05-14 17:59:40.996831
24	USER_DELETED	\N	6	testvmktcsez@example.com	\N	2025-05-14 18:03:58.772315
25	USER_DELETED	\N	\N	testvmktcsez@example.com	\N	2025-05-14 18:03:58.78152
26	USER_DELETED	\N	\N	testnwiudrel@example.com	\N	2025-05-14 18:05:03.391082
27	ROLE_CHANGED	\N	6	user	Mini Admin	2025-05-14 18:52:00.524345
28	ROLE_CHANGED	\N	6	Mini Admin	user	2025-05-14 18:52:03.397077
29	USER_DELETED	\N	\N	testchdldtby@example.com	\N	2025-05-14 19:00:49.950103
30	USER_DELETED	\N	\N	testeaylacdl@example.com	\N	2025-05-14 19:00:51.920275
31	USER_DELETED	\N	\N	testyfbkyqbw@example.com	\N	2025-05-14 19:00:53.582654
32	USER_DELETED	\N	\N	testxxcmxlhf@example.com	\N	2025-05-17 17:20:09.651835
34	USER_DELETED	\N	\N	testqirdwpsl@example.com	\N	2025-05-17 17:20:40.30508
41	USER_DELETED	\N	6	testnehprqzs@example.com	\N	2025-05-19 09:38:24.073336
35	ROLE_CHANGED	\N	6	user	admin	2025-05-17 17:20:45.400798
40	ROLE_CHANGED	\N	6	admin	Moderator kursów 	2025-05-19 09:24:28.241422
42	USER_DELETED	\N	6	testrxcjpmfo@example.com	\N	2025-05-27 21:54:34.052854
43	USER_DELETED	\N	6	testrxcjpmfo@example.com	\N	2025-05-27 21:56:19.50851
44	USER_DELETED	\N	6	testqlgejwpb@example.com	\N	2025-05-27 21:56:24.513152
36	ROLE_CHANGED	\N	6	user	Moderator kursów 	2025-05-17 17:21:31.013454
45	USER_DELETED	\N	6	testreknllrp@example.com	\N	2025-05-28 10:30:36.011802
46	USER_DELETED	\N	6	marcin@dudek.pl	\N	2025-05-28 12:42:04.630262
47	USER_DELETED	\N	6	marcin@dudek.pl	\N	2025-05-28 12:42:04.633171
33	ROLE_CHANGED	\N	6	user	Moderator kursów 	2025-05-17 17:20:25.267355
48	USER_DELETED	\N	6	adriannowak@interia.pl	\N	2025-05-28 12:43:41.992708
49	USER_DELETED	\N	6	adriannowak@interia.pl	\N	2025-05-28 12:43:41.99532
19	ROLE_CHANGED	\N	6	user	Mini Admin	2025-05-14 17:45:45.69314
50	USER_DELETED	\N	6	michal.bernardy420@interia.pl	\N	2025-05-28 12:56:03.266185
51	USER_DELETED	\N	6	michal.bernardy420@interia.pl	\N	2025-05-28 12:56:03.269556
37	ROLE_CHANGED	\N	6	Mini Admin	admin	2025-05-17 17:21:51.552724
52	USER_DELETED	\N	6	jtokarczyk@interia.pl	\N	2025-05-28 12:59:57.627427
38	ROLE_CHANGED	\N	\N	admin	user	2025-05-17 17:22:12.517368
53	USER_DELETED	\N	6	asd@asd.pl	\N	2025-05-28 13:02:00.808606
54	USER_DELETED	\N	6	asd@asd.pl	\N	2025-05-28 13:04:40.944769
55	ROLE_CHANGED	\N	6	user	Moderator kursów 	2025-05-28 13:05:49.823513
56	USER_DELETED	\N	6	te@te.pl	\N	2025-05-28 13:06:08.885617
57	USER_DELETED	\N	6	te@te.pl	\N	2025-05-28 13:06:08.887651
58	ROLE_CHANGED	\N	6	user	Moderator kursów 	2025-05-28 13:06:55.757401
59	USER_DELETED	\N	6	mdudek@interia.pl	\N	2025-05-28 13:06:58.825735
60	ROLE_CHANGED	\N	6	user	Mini Admin	2025-05-28 13:09:21.187649
61	ROLE_CHANGED	\N	6	Mini Admin	Moderator kursów 	2025-05-28 22:14:01.359062
62	ROLE_CHANGED	\N	6	Moderator kursów 	admin	2025-05-30 12:18:41.063252
63	ROLE_CHANGED	\N	6	admin	Moderator kursów 	2025-05-30 12:18:49.561208
64	USER_DELETED	\N	6	a@a.pl	\N	2025-05-30 12:23:56.774046
66	ROLE_CHANGED	\N	6	user	admin	2025-05-30 19:57:39.313823
67	USER_DELETED	\N	6	jtokarczyk@interia.pl	\N	2025-05-30 19:58:00.901003
68	USER_DELETED	\N	6	jtokarczyk@interia.pl	\N	2025-05-30 19:58:00.90304
65	ROLE_CHANGED	\N	6	user	Mini Admin	2025-05-30 15:28:06.575735
69	ROLE_CHANGED	\N	6	Mini Admin	admin	2025-05-30 20:08:39.87083
70	ROLE_CHANGED	\N	6	admin	Mini Admin	2025-05-30 20:08:43.464651
71	ROLE_CHANGED	\N	6	Mini Admin	admin	2025-05-30 20:08:45.997486
72	USER_DELETED	\N	6	marcindudek@interia.pl	\N	2025-05-30 20:08:48.81683
73	USER_DELETED	\N	6	marcindudek@interia.pl	\N	2025-05-30 20:08:48.818304
80	ROLE_CHANGED	\N	6	user	admin	2025-05-31 11:12:22.592971
\.


--
-- TOC entry 5402 (class 0 OID 98523)
-- Dependencies: 264
-- Data for Name: user_logs_y202506; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202506 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
91	ROLE_CHANGED	82	6	user	admin	2025-06-06 16:58:01.764998
92	ROLE_CHANGED	82	6	admin	Testowa rola	2025-06-06 16:58:04.143948
93	USER_DELETED	\N	6	krradziak@interia.pl	\N	2025-06-06 17:06:15.721417
94	USER_DELETED	\N	6	adriannn@interia.pl	\N	2025-06-06 17:06:17.52008
95	USER_DELETED	\N	\N	qwe@qwe.pl	\N	2025-06-07 10:52:50.147862
96	ROLE_CHANGED	82	6	Testowa rola	admin	2025-06-08 22:42:58.792168
97	ROLE_CHANGED	82	6	admin	Mini Admin	2025-06-08 22:43:00.75451
98	ROLE_CHANGED	82	6	Mini Admin	Testowa rola	2025-06-08 22:43:03.087581
99	ROLE_CHANGED	82	6	Testowa rola	user	2025-06-08 22:43:05.141364
100	ROLE_CHANGED	79	6	user	Mini Admin	2025-06-08 22:43:08.703133
101	ROLE_CHANGED	79	6	Mini Admin	user	2025-06-08 22:43:10.283801
102	ROLE_CHANGED	79	6	user	Testowa rola	2025-06-08 22:43:12.059391
103	ROLE_CHANGED	79	6	Testowa rola	user	2025-06-08 22:43:13.644766
104	ROLE_CHANGED	82	6	user	Zarządzanie użytkownikami 	2025-06-08 22:50:49.149959
105	ROLE_CHANGED	82	6	Zarządzanie użytkownikami 	Testowa rola	2025-06-08 23:46:43.104257
106	ROLE_CHANGED	82	\N	\N	\N	2025-06-08 23:49:22.06275
107	ROLE_CHANGED	82	6	\N	user	2025-06-08 23:50:04.159683
108	ROLE_CHANGED	82	6	user	Zarządzanie użytkownikami 	2025-06-08 23:50:14.58378
109	ROLE_CHANGED	82	6	\N	\N	2025-06-08 23:50:20.254113
110	ROLE_CHANGED	82	6	\N	user	2025-06-08 23:51:26.229439
111	ROLE_CHANGED	6	6	admin	user	2025-06-08 23:55:32.154182
112	ROLE_CHANGED	6	\N	user	admin	2025-06-08 23:56:55.216966
113	ROLE_CHANGED	79	6	user	Mini Admin	2025-06-08 23:59:15.644241
114	ROLE_CHANGED	79	6	Mini Admin	przykładową role 	2025-06-09 00:00:09.429552
115	ROLE_CHANGED	79	6	przykładową role 	Mini Admin	2025-06-09 00:01:33.603664
116	ROLE_CHANGED	79	6	Mini Admin	testowa rola 	2025-06-09 00:02:19.501367
117	ROLE_CHANGED	79	\N	\N	\N	2025-06-09 00:03:49.961142
118	ROLE_CHANGED	79	6	\N	user	2025-06-09 00:03:56.316995
119	ROLE_CHANGED	79	6	user	test	2025-06-09 00:05:18.397549
120	ROLE_CHANGED	79	6	test	user	2025-06-09 14:03:47.415964
121	ROLE_CHANGED	79	6	user	qwe	2025-06-09 19:55:38.310943
122	USER_DELETED	\N	6	mmaria@interia.pl	\N	2025-06-10 09:31:58.717382
\.


--
-- TOC entry 5403 (class 0 OID 98530)
-- Dependencies: 265
-- Data for Name: user_logs_y202507; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202507 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5404 (class 0 OID 98537)
-- Dependencies: 266
-- Data for Name: user_logs_y202508; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202508 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5405 (class 0 OID 98544)
-- Dependencies: 267
-- Data for Name: user_logs_y202509; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202509 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5406 (class 0 OID 98551)
-- Dependencies: 268
-- Data for Name: user_test_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_test_answers (id, attempt_id, block_id, selected_answer_id, text_answer, json_answer, is_correct, points_awarded) FROM stdin;
90	2287	13	49	\N	\N	t	0
91	2287	15	60	\N	\N	t	0
92	2288	21	83	\N	\N	t	0
93	2288	22	85	\N	\N	t	0
94	2289	19	73	\N	\N	t	0
95	2289	20	79	\N	\N	t	0
96	2289	23	\N	seria 3 e90	\N	t	0
97	2289	26	95	{"rightItem":"M4"}	\N	t	0
98	2289	26	96	{"rightItem":"Stringer"}	\N	t	0
99	2289	26	97	{"rightItem":"RS5"}	\N	t	0
100	2289	26	98	{"rightItem":"CLA"}	\N	t	0
101	2289	27	99	{"rightItem":"1"}	\N	t	0
102	2289	27	100	{"rightItem":"2"}	\N	t	0
103	2289	27	101	{"rightItem":"3"}	\N	t	0
104	2289	28	102	\N	\N	t	0
\.


--
-- TOC entry 5408 (class 0 OID 98559)
-- Dependencies: 270
-- Data for Name: user_test_attempts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_test_attempts (id, user_id, test_id, start_time, end_time, score, max_score, passed, created_at) FROM stdin;
2287	82	3	2025-06-05 13:49:32.953	2025-06-05 13:49:32.951	4	4	t	2025-06-05 13:49:32.953
2288	82	6	2025-06-05 13:49:43.554	2025-06-05 13:49:43.553	5	5	t	2025-06-05 13:49:43.554
2289	82	4	2025-06-05 13:50:34.246	2025-06-05 13:50:34.244	10	10	t	2025-06-05 13:50:34.246
\.


--
-- TOC entry 5410 (class 0 OID 98568)
-- Dependencies: 272
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, email, password, created_at, updated_at, role_id, is_verified, verification_token_id, reset_password_token, reset_password_expires, last_password_change, first_login, last_login) FROM stdin;
85	Adrian	nowak	anowak@interia.pl	$2b$10$DZyIjrP//6YUM0oTMN4qn.OuCDLqzUYvvBOkagTQxoitFqpxLF9He	2025-06-09 19:32:06.085867	2025-06-09 19:32:06.085867	2	f	80	\N	\N	\N	t	2025-06-09 19:32:22.010366
79	Jakub	Tokarczyk	jtokarczyk@interia.pl	$2b$10$CFmLRv0pxyulYosRmye/ruocrJwXOY/JA4y0KMCcDuAT47CHFqkTG	2025-05-31 10:49:57.192135	2025-06-09 19:55:38.310943	22	t	\N	\N	\N	\N	f	2025-06-09 19:55:46.509376
82	Marcin	Dudek	marcindudek@interia.pl	$2b$10$HYYI76CgtCHfGTWM3TsCr.Xtz5gUSz.yXWU/GEjyWRZSV1Z/pjAka	2025-06-05 15:37:30.259308	2025-06-08 23:51:26.229439	2	t	\N	\N	\N	\N	f	2025-06-08 23:50:33.11962
87	krzyszyof	Wyszowski	kwyszowski@interia.pl	$2b$10$KywHQ8OI02p5BWnOffRSBug2co394Fq6RVFK7.Mx9svlYqi0Ue.BC	2025-06-10 09:32:35.850637	2025-06-10 09:32:35.850637	2	t	\N	\N	\N	\N	f	2025-06-10 09:34:56.904736
6	test	test	test@testowy.pl	$2b$10$iY5PO4x5z/cWBKOSbB49UOq8nh8UA0B2ulQoNlriXrrMMsXIi7zOi	2025-04-06 20:18:40.52964	2025-06-08 23:55:32.154182	1	t	\N	\N	\N	\N	f	2025-06-10 09:35:28.074053
\.


--
-- TOC entry 5412 (class 0 OID 98579)
-- Dependencies: 274
-- Data for Name: verification_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_tokens (id, user_id, verification_token, created_at, expires_at) FROM stdin;
80	85	$2b$10$i2s8.zc2Zo2GXyCdyke1NeIIBEnvxnKOP4Ht8TEVYz3rr2oN4tqxi	2025-06-09 19:32:20.366235	2025-06-09 19:42:20.364
\.


--
-- TOC entry 5414 (class 0 OID 98584)
-- Dependencies: 276
-- Data for Name: waf_security_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.waf_security_events (id, event_id, event_type, ip_address, endpoint, user_agent, description, risk_level, action_taken, created_at) FROM stdin;
172	evt_1749415908493_h35qcuehe	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:48.537304
173	evt_1749415908717_00x2lm68c	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:48.718795
174	evt_1749415908951_ib9cgdqa7	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:48.953087
175	evt_1749415909208_pvjtx3yvc	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:49.209222
176	evt_1749415909569_bm53w3jna	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:49.570393
177	evt_1749415909756_am72sl5md	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:49.758726
178	evt_1749415910025_pqsw2j1gl	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:50.026967
179	evt_1749415910221_bhkyhavrt	rate_limit	::1	/api/courses/33/chapters/45		Rate limit exceeded: 100 requests	medium	blocked	2025-06-08 22:51:50.222177
180	evt_1749484285511_gxuw454z9	sql_injection	::ffff:127.0.0.1	/api/questions	vscode-restclient	SQL injection attempt in field 'title': Test'; DROP TABLE users; --	high	blocked	2025-06-09 17:51:25.566251
181	evt_1749484294704_1afunqw6h	sql_injection	::ffff:127.0.0.1	/api/questions	vscode-restclient	SQL injection attempt in field 'title': Test'; DROP TABLE users; --	high	blocked	2025-06-09 17:51:34.705455
182	evt_1749484295479_wtfn96ukl	sql_injection	::ffff:127.0.0.1	/api/questions	vscode-restclient	SQL injection attempt in field 'title': Test'; DROP TABLE users; --	high	blocked	2025-06-09 17:51:35.485933
183	evt_1749484301719_i1mpuxm8i	xss	::ffff:127.0.0.1	/api/questions	vscode-restclient	XSS attempt in field 'content': <script>alert('XSS')</script>	high	blocked	2025-06-09 17:51:41.72075
184	evt_1749484303522_sjnna753w	xss	::ffff:127.0.0.1	/api/questions	vscode-restclient	XSS attempt in field 'content': <script>alert('XSS')</script>	high	blocked	2025-06-09 17:51:43.522985
\.


--
-- TOC entry 5448 (class 0 OID 0)
-- Dependencies: 219
-- Name: answer_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.answer_attributes_id_seq', 30, true);


--
-- TOC entry 5449 (class 0 OID 0)
-- Dependencies: 221
-- Name: certificates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificates_id_seq', 29, true);


--
-- TOC entry 5450 (class 0 OID 0)
-- Dependencies: 223
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_block_attributes_id_seq', 123083, true);


--
-- TOC entry 5451 (class 0 OID 0)
-- Dependencies: 225
-- Name: chapter_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_blocks_id_seq', 53527, true);


--
-- TOC entry 5452 (class 0 OID 0)
-- Dependencies: 227
-- Name: chapters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapters_id_seq', 48, true);


--
-- TOC entry 5453 (class 0 OID 0)
-- Dependencies: 229
-- Name: course_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_answers_id_seq', 57, true);


--
-- TOC entry 5454 (class 0 OID 0)
-- Dependencies: 231
-- Name: course_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_logs_id_seq', 79, true);


--
-- TOC entry 5455 (class 0 OID 0)
-- Dependencies: 237
-- Name: course_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_notes_id_seq', 4, true);


--
-- TOC entry 5456 (class 0 OID 0)
-- Dependencies: 239
-- Name: course_questions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_questions_id_seq', 19, true);


--
-- TOC entry 5457 (class 0 OID 0)
-- Dependencies: 241
-- Name: courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.courses_id_seq', 35, true);


--
-- TOC entry 5458 (class 0 OID 0)
-- Dependencies: 243
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 832, true);


--
-- TOC entry 5459 (class 0 OID 0)
-- Dependencies: 245
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permissions_id_seq', 13, true);


--
-- TOC entry 5460 (class 0 OID 0)
-- Dependencies: 248
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 22, true);


--
-- TOC entry 5461 (class 0 OID 0)
-- Dependencies: 250
-- Name: test_block_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_block_answers_id_seq', 184, true);


--
-- TOC entry 5462 (class 0 OID 0)
-- Dependencies: 252
-- Name: test_block_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_block_attributes_id_seq', 4, true);


--
-- TOC entry 5463 (class 0 OID 0)
-- Dependencies: 254
-- Name: test_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_blocks_id_seq', 54, true);


--
-- TOC entry 5464 (class 0 OID 0)
-- Dependencies: 256
-- Name: tests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tests_id_seq', 16, true);


--
-- TOC entry 5465 (class 0 OID 0)
-- Dependencies: 258
-- Name: user_chapter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_chapter_id_seq', 1, false);


--
-- TOC entry 5466 (class 0 OID 0)
-- Dependencies: 260
-- Name: user_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_courses_id_seq', 15, true);


--
-- TOC entry 5467 (class 0 OID 0)
-- Dependencies: 262
-- Name: user_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_logs_id_seq', 122, true);


--
-- TOC entry 5468 (class 0 OID 0)
-- Dependencies: 269
-- Name: user_test_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_test_answers_id_seq', 119, true);


--
-- TOC entry 5469 (class 0 OID 0)
-- Dependencies: 271
-- Name: user_test_attempts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_test_attempts_id_seq', 2292, true);


--
-- TOC entry 5470 (class 0 OID 0)
-- Dependencies: 273
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 87, true);


--
-- TOC entry 5471 (class 0 OID 0)
-- Dependencies: 275
-- Name: verification_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_tokens_id_seq', 82, true);


--
-- TOC entry 5472 (class 0 OID 0)
-- Dependencies: 277
-- Name: waf_security_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.waf_security_events_id_seq', 244, true);


--
-- TOC entry 4987 (class 2606 OID 98619)
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4989 (class 2606 OID 98621)
-- Name: answer_attributes answer_attributes_answer_id_attribute_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_answer_id_attribute_name_key UNIQUE (answer_id, attribute_name);


--
-- TOC entry 4991 (class 2606 OID 98623)
-- Name: answer_attributes answer_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 4995 (class 2606 OID 98625)
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);


--
-- TOC entry 4997 (class 2606 OID 98627)
-- Name: chapter_block_attributes chapter_block_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 4999 (class 2606 OID 98629)
-- Name: chapter_blocks chapter_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_pkey PRIMARY KEY (id);


--
-- TOC entry 5001 (class 2606 OID 98631)
-- Name: chapters chapters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_pkey PRIMARY KEY (id);


--
-- TOC entry 5003 (class 2606 OID 98633)
-- Name: course_answers course_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 5007 (class 2606 OID 98635)
-- Name: course_logs course_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs
    ADD CONSTRAINT course_logs_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5014 (class 2606 OID 98637)
-- Name: course_logs_y202505 course_logs_y202505_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202505
    ADD CONSTRAINT course_logs_y202505_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5019 (class 2606 OID 98639)
-- Name: course_logs_y202506 course_logs_y202506_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202506
    ADD CONSTRAINT course_logs_y202506_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5024 (class 2606 OID 98641)
-- Name: course_logs_y202507 course_logs_y202507_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202507
    ADD CONSTRAINT course_logs_y202507_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5031 (class 2606 OID 98643)
-- Name: course_logs_y202508 course_logs_y202508_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202508
    ADD CONSTRAINT course_logs_y202508_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5036 (class 2606 OID 98645)
-- Name: course_notes course_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_notes
    ADD CONSTRAINT course_notes_pkey PRIMARY KEY (id);


--
-- TOC entry 5041 (class 2606 OID 98647)
-- Name: course_questions course_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_pkey PRIMARY KEY (id);


--
-- TOC entry 5044 (class 2606 OID 98649)
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- TOC entry 5047 (class 2606 OID 98651)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 5049 (class 2606 OID 98653)
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 5051 (class 2606 OID 98655)
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- TOC entry 5053 (class 2606 OID 98657)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 5056 (class 2606 OID 98659)
-- Name: test_block_answers test_block_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers
    ADD CONSTRAINT test_block_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 5059 (class 2606 OID 98661)
-- Name: test_block_attributes test_block_attributes_block_id_attribute_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_block_id_attribute_name_key UNIQUE (block_id, attribute_name);


--
-- TOC entry 5061 (class 2606 OID 98663)
-- Name: test_block_attributes test_block_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 5064 (class 2606 OID 98665)
-- Name: test_blocks test_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks
    ADD CONSTRAINT test_blocks_pkey PRIMARY KEY (id);


--
-- TOC entry 5066 (class 2606 OID 98667)
-- Name: tests tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_pkey PRIMARY KEY (id);


--
-- TOC entry 5068 (class 2606 OID 98669)
-- Name: user_chapter user_chapter_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_pkey PRIMARY KEY (id);


--
-- TOC entry 5071 (class 2606 OID 98671)
-- Name: user_courses user_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_pkey PRIMARY KEY (id);


--
-- TOC entry 5077 (class 2606 OID 98673)
-- Name: user_logs user_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs
    ADD CONSTRAINT user_logs_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5083 (class 2606 OID 98675)
-- Name: user_logs_y202505 user_logs_y202505_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202505
    ADD CONSTRAINT user_logs_y202505_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5090 (class 2606 OID 98677)
-- Name: user_logs_y202506 user_logs_y202506_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202506
    ADD CONSTRAINT user_logs_y202506_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5097 (class 2606 OID 98679)
-- Name: user_logs_y202507 user_logs_y202507_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202507
    ADD CONSTRAINT user_logs_y202507_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5104 (class 2606 OID 98681)
-- Name: user_logs_y202508 user_logs_y202508_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202508
    ADD CONSTRAINT user_logs_y202508_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5111 (class 2606 OID 98683)
-- Name: user_logs_y202509 user_logs_y202509_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202509
    ADD CONSTRAINT user_logs_y202509_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5116 (class 2606 OID 98685)
-- Name: user_test_answers user_test_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 5120 (class 2606 OID 98687)
-- Name: user_test_attempts user_test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 5123 (class 2606 OID 98689)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5125 (class 2606 OID 98691)
-- Name: verification_tokens verificationtokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_pkey PRIMARY KEY (id);


--
-- TOC entry 5130 (class 2606 OID 98693)
-- Name: waf_security_events waf_security_events_event_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waf_security_events
    ADD CONSTRAINT waf_security_events_event_id_key UNIQUE (event_id);


--
-- TOC entry 5132 (class 2606 OID 98695)
-- Name: waf_security_events waf_security_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waf_security_events
    ADD CONSTRAINT waf_security_events_pkey PRIMARY KEY (id);


--
-- TOC entry 4993 (class 1259 OID 98696)
-- Name: certificates_certificate_code_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX certificates_certificate_code_key ON public.certificates USING btree (certificate_code);


--
-- TOC entry 5008 (class 1259 OID 98697)
-- Name: idx_course_logs_course_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_course_id ON ONLY public.course_logs USING btree (course_id);


--
-- TOC entry 5011 (class 1259 OID 98698)
-- Name: course_logs_y202505_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_course_id_idx ON public.course_logs_y202505 USING btree (course_id);


--
-- TOC entry 5009 (class 1259 OID 98699)
-- Name: idx_course_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_created_at ON ONLY public.course_logs USING btree (created_at);


--
-- TOC entry 5012 (class 1259 OID 98700)
-- Name: course_logs_y202505_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_created_at_idx ON public.course_logs_y202505 USING btree (created_at);


--
-- TOC entry 5010 (class 1259 OID 98701)
-- Name: idx_course_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_user_id ON ONLY public.course_logs USING btree (user_id);


--
-- TOC entry 5015 (class 1259 OID 98702)
-- Name: course_logs_y202505_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_user_id_idx ON public.course_logs_y202505 USING btree (user_id);


--
-- TOC entry 5016 (class 1259 OID 98703)
-- Name: course_logs_y202506_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_course_id_idx ON public.course_logs_y202506 USING btree (course_id);


--
-- TOC entry 5017 (class 1259 OID 98704)
-- Name: course_logs_y202506_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_created_at_idx ON public.course_logs_y202506 USING btree (created_at);


--
-- TOC entry 5020 (class 1259 OID 98705)
-- Name: course_logs_y202506_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_user_id_idx ON public.course_logs_y202506 USING btree (user_id);


--
-- TOC entry 5021 (class 1259 OID 98706)
-- Name: course_logs_y202507_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_course_id_idx ON public.course_logs_y202507 USING btree (course_id);


--
-- TOC entry 5022 (class 1259 OID 98707)
-- Name: course_logs_y202507_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_created_at_idx ON public.course_logs_y202507 USING btree (created_at);


--
-- TOC entry 5025 (class 1259 OID 98708)
-- Name: course_logs_y202507_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_user_id_idx ON public.course_logs_y202507 USING btree (user_id);


--
-- TOC entry 5028 (class 1259 OID 98709)
-- Name: course_logs_y202508_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202508_course_id_idx ON public.course_logs_y202508 USING btree (course_id);


--
-- TOC entry 5029 (class 1259 OID 98710)
-- Name: course_logs_y202508_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202508_created_at_idx ON public.course_logs_y202508 USING btree (created_at);


--
-- TOC entry 5032 (class 1259 OID 98711)
-- Name: course_logs_y202508_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202508_user_id_idx ON public.course_logs_y202508 USING btree (user_id);


--
-- TOC entry 5039 (class 1259 OID 98712)
-- Name: course_questions_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_questions_course_id_idx ON public.course_questions USING btree (course_id);


--
-- TOC entry 5042 (class 1259 OID 98713)
-- Name: course_questions_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_questions_user_id_idx ON public.course_questions USING btree (user_id);


--
-- TOC entry 4992 (class 1259 OID 98714)
-- Name: idx_answer_attributes_answer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_answer_attributes_answer_id ON public.answer_attributes USING btree (answer_id);


--
-- TOC entry 5004 (class 1259 OID 98715)
-- Name: idx_course_answers_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_answers_question_id ON public.course_answers USING btree (question_id);


--
-- TOC entry 5005 (class 1259 OID 98716)
-- Name: idx_course_answers_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_answers_user_id ON public.course_answers USING btree (user_id);


--
-- TOC entry 5026 (class 1259 OID 98717)
-- Name: idx_course_logs_y202507_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202507_action_type ON public.course_logs_y202507 USING btree (action_type, created_at);


--
-- TOC entry 5027 (class 1259 OID 98718)
-- Name: idx_course_logs_y202507_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202507_user_id ON public.course_logs_y202507 USING btree (user_id, created_at);


--
-- TOC entry 5033 (class 1259 OID 98719)
-- Name: idx_course_logs_y202508_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202508_action_type ON public.course_logs_y202508 USING btree (action_type, created_at);


--
-- TOC entry 5034 (class 1259 OID 98720)
-- Name: idx_course_logs_y202508_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202508_user_id ON public.course_logs_y202508 USING btree (user_id, created_at);


--
-- TOC entry 5037 (class 1259 OID 98721)
-- Name: idx_course_notes_course_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_notes_course_id ON public.course_notes USING btree (course_id);


--
-- TOC entry 5038 (class 1259 OID 98722)
-- Name: idx_course_notes_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_notes_user_id ON public.course_notes USING btree (user_id);


--
-- TOC entry 5045 (class 1259 OID 98723)
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- TOC entry 5054 (class 1259 OID 98724)
-- Name: idx_test_block_answers_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_block_answers_block_id ON public.test_block_answers USING btree (block_id);


--
-- TOC entry 5057 (class 1259 OID 98725)
-- Name: idx_test_block_attributes_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_block_attributes_block_id ON public.test_block_attributes USING btree (block_id);


--
-- TOC entry 5062 (class 1259 OID 98726)
-- Name: idx_test_blocks_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_blocks_test_id ON public.test_blocks USING btree (test_id);


--
-- TOC entry 5073 (class 1259 OID 98727)
-- Name: idx_user_logs_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_action_type ON ONLY public.user_logs USING btree (action_type);


--
-- TOC entry 5074 (class 1259 OID 98728)
-- Name: idx_user_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_created_at ON ONLY public.user_logs USING btree (created_at);


--
-- TOC entry 5075 (class 1259 OID 98729)
-- Name: idx_user_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_user_id ON ONLY public.user_logs USING btree (user_id);


--
-- TOC entry 5078 (class 1259 OID 98730)
-- Name: idx_user_logs_y202505_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202505_action_type ON public.user_logs_y202505 USING btree (action_type, created_at);


--
-- TOC entry 5079 (class 1259 OID 98731)
-- Name: idx_user_logs_y202505_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202505_user_id ON public.user_logs_y202505 USING btree (user_id, created_at);


--
-- TOC entry 5085 (class 1259 OID 98732)
-- Name: idx_user_logs_y202506_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202506_action_type ON public.user_logs_y202506 USING btree (action_type, created_at);


--
-- TOC entry 5086 (class 1259 OID 98733)
-- Name: idx_user_logs_y202506_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202506_user_id ON public.user_logs_y202506 USING btree (user_id, created_at);


--
-- TOC entry 5092 (class 1259 OID 98734)
-- Name: idx_user_logs_y202507_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202507_action_type ON public.user_logs_y202507 USING btree (action_type, created_at);


--
-- TOC entry 5093 (class 1259 OID 98735)
-- Name: idx_user_logs_y202507_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202507_user_id ON public.user_logs_y202507 USING btree (user_id, created_at);


--
-- TOC entry 5099 (class 1259 OID 98736)
-- Name: idx_user_logs_y202508_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202508_action_type ON public.user_logs_y202508 USING btree (action_type, created_at);


--
-- TOC entry 5100 (class 1259 OID 98737)
-- Name: idx_user_logs_y202508_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202508_user_id ON public.user_logs_y202508 USING btree (user_id, created_at);


--
-- TOC entry 5106 (class 1259 OID 98738)
-- Name: idx_user_logs_y202509_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202509_action_type ON public.user_logs_y202509 USING btree (action_type, created_at);


--
-- TOC entry 5107 (class 1259 OID 98739)
-- Name: idx_user_logs_y202509_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202509_user_id ON public.user_logs_y202509 USING btree (user_id, created_at);


--
-- TOC entry 5113 (class 1259 OID 98740)
-- Name: idx_user_test_answers_attempt_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_answers_attempt_id ON public.user_test_answers USING btree (attempt_id);


--
-- TOC entry 5114 (class 1259 OID 98741)
-- Name: idx_user_test_answers_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_answers_block_id ON public.user_test_answers USING btree (block_id);


--
-- TOC entry 5117 (class 1259 OID 98742)
-- Name: idx_user_test_attempts_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_attempts_test_id ON public.user_test_attempts USING btree (test_id);


--
-- TOC entry 5118 (class 1259 OID 98743)
-- Name: idx_user_test_attempts_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_attempts_user_id ON public.user_test_attempts USING btree (user_id);


--
-- TOC entry 5126 (class 1259 OID 98744)
-- Name: idx_waf_events_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_waf_events_created ON public.waf_security_events USING btree (created_at);


--
-- TOC entry 5127 (class 1259 OID 98745)
-- Name: idx_waf_events_ip; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_waf_events_ip ON public.waf_security_events USING btree (ip_address);


--
-- TOC entry 5128 (class 1259 OID 98746)
-- Name: idx_waf_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_waf_events_type ON public.waf_security_events USING btree (event_type);


--
-- TOC entry 5069 (class 1259 OID 98747)
-- Name: user_chapter_user_id_chapter_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_chapter_user_id_chapter_id_key ON public.user_chapter USING btree (user_id, chapter_id);


--
-- TOC entry 5072 (class 1259 OID 98748)
-- Name: user_courses_user_id_course_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_courses_user_id_course_id_key ON public.user_courses USING btree (user_id, course_id);


--
-- TOC entry 5080 (class 1259 OID 98749)
-- Name: user_logs_y202505_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_action_type_idx ON public.user_logs_y202505 USING btree (action_type);


--
-- TOC entry 5081 (class 1259 OID 98750)
-- Name: user_logs_y202505_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_created_at_idx ON public.user_logs_y202505 USING btree (created_at);


--
-- TOC entry 5084 (class 1259 OID 98751)
-- Name: user_logs_y202505_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_user_id_idx ON public.user_logs_y202505 USING btree (user_id);


--
-- TOC entry 5087 (class 1259 OID 98752)
-- Name: user_logs_y202506_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_action_type_idx ON public.user_logs_y202506 USING btree (action_type);


--
-- TOC entry 5088 (class 1259 OID 98753)
-- Name: user_logs_y202506_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_created_at_idx ON public.user_logs_y202506 USING btree (created_at);


--
-- TOC entry 5091 (class 1259 OID 98754)
-- Name: user_logs_y202506_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_user_id_idx ON public.user_logs_y202506 USING btree (user_id);


--
-- TOC entry 5094 (class 1259 OID 98755)
-- Name: user_logs_y202507_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_action_type_idx ON public.user_logs_y202507 USING btree (action_type);


--
-- TOC entry 5095 (class 1259 OID 98756)
-- Name: user_logs_y202507_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_created_at_idx ON public.user_logs_y202507 USING btree (created_at);


--
-- TOC entry 5098 (class 1259 OID 98757)
-- Name: user_logs_y202507_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_user_id_idx ON public.user_logs_y202507 USING btree (user_id);


--
-- TOC entry 5101 (class 1259 OID 98758)
-- Name: user_logs_y202508_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_action_type_idx ON public.user_logs_y202508 USING btree (action_type);


--
-- TOC entry 5102 (class 1259 OID 98759)
-- Name: user_logs_y202508_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_created_at_idx ON public.user_logs_y202508 USING btree (created_at);


--
-- TOC entry 5105 (class 1259 OID 98760)
-- Name: user_logs_y202508_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_user_id_idx ON public.user_logs_y202508 USING btree (user_id);


--
-- TOC entry 5108 (class 1259 OID 98761)
-- Name: user_logs_y202509_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_action_type_idx ON public.user_logs_y202509 USING btree (action_type);


--
-- TOC entry 5109 (class 1259 OID 98762)
-- Name: user_logs_y202509_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_created_at_idx ON public.user_logs_y202509 USING btree (created_at);


--
-- TOC entry 5112 (class 1259 OID 98763)
-- Name: user_logs_y202509_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_user_id_idx ON public.user_logs_y202509 USING btree (user_id);


--
-- TOC entry 5121 (class 1259 OID 98764)
-- Name: users_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);


--
-- TOC entry 5133 (class 0 OID 0)
-- Name: course_logs_y202505_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202505_course_id_idx;


--
-- TOC entry 5134 (class 0 OID 0)
-- Name: course_logs_y202505_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202505_created_at_idx;


--
-- TOC entry 5135 (class 0 OID 0)
-- Name: course_logs_y202505_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202505_pkey;


--
-- TOC entry 5136 (class 0 OID 0)
-- Name: course_logs_y202505_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202505_user_id_idx;


--
-- TOC entry 5137 (class 0 OID 0)
-- Name: course_logs_y202506_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202506_course_id_idx;


--
-- TOC entry 5138 (class 0 OID 0)
-- Name: course_logs_y202506_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202506_created_at_idx;


--
-- TOC entry 5139 (class 0 OID 0)
-- Name: course_logs_y202506_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202506_pkey;


--
-- TOC entry 5140 (class 0 OID 0)
-- Name: course_logs_y202506_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202506_user_id_idx;


--
-- TOC entry 5141 (class 0 OID 0)
-- Name: course_logs_y202507_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202507_course_id_idx;


--
-- TOC entry 5142 (class 0 OID 0)
-- Name: course_logs_y202507_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202507_created_at_idx;


--
-- TOC entry 5143 (class 0 OID 0)
-- Name: course_logs_y202507_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202507_pkey;


--
-- TOC entry 5144 (class 0 OID 0)
-- Name: course_logs_y202507_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202507_user_id_idx;


--
-- TOC entry 5145 (class 0 OID 0)
-- Name: course_logs_y202508_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202508_course_id_idx;


--
-- TOC entry 5146 (class 0 OID 0)
-- Name: course_logs_y202508_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202508_created_at_idx;


--
-- TOC entry 5147 (class 0 OID 0)
-- Name: course_logs_y202508_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202508_pkey;


--
-- TOC entry 5148 (class 0 OID 0)
-- Name: course_logs_y202508_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202508_user_id_idx;


--
-- TOC entry 5149 (class 0 OID 0)
-- Name: user_logs_y202505_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202505_action_type_idx;


--
-- TOC entry 5150 (class 0 OID 0)
-- Name: user_logs_y202505_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202505_created_at_idx;


--
-- TOC entry 5151 (class 0 OID 0)
-- Name: user_logs_y202505_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202505_pkey;


--
-- TOC entry 5152 (class 0 OID 0)
-- Name: user_logs_y202505_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202505_user_id_idx;


--
-- TOC entry 5153 (class 0 OID 0)
-- Name: user_logs_y202506_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202506_action_type_idx;


--
-- TOC entry 5154 (class 0 OID 0)
-- Name: user_logs_y202506_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202506_created_at_idx;


--
-- TOC entry 5155 (class 0 OID 0)
-- Name: user_logs_y202506_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202506_pkey;


--
-- TOC entry 5156 (class 0 OID 0)
-- Name: user_logs_y202506_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202506_user_id_idx;


--
-- TOC entry 5157 (class 0 OID 0)
-- Name: user_logs_y202507_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202507_action_type_idx;


--
-- TOC entry 5158 (class 0 OID 0)
-- Name: user_logs_y202507_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202507_created_at_idx;


--
-- TOC entry 5159 (class 0 OID 0)
-- Name: user_logs_y202507_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202507_pkey;


--
-- TOC entry 5160 (class 0 OID 0)
-- Name: user_logs_y202507_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202507_user_id_idx;


--
-- TOC entry 5161 (class 0 OID 0)
-- Name: user_logs_y202508_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202508_action_type_idx;


--
-- TOC entry 5162 (class 0 OID 0)
-- Name: user_logs_y202508_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202508_created_at_idx;


--
-- TOC entry 5163 (class 0 OID 0)
-- Name: user_logs_y202508_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202508_pkey;


--
-- TOC entry 5164 (class 0 OID 0)
-- Name: user_logs_y202508_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202508_user_id_idx;


--
-- TOC entry 5165 (class 0 OID 0)
-- Name: user_logs_y202509_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202509_action_type_idx;


--
-- TOC entry 5166 (class 0 OID 0)
-- Name: user_logs_y202509_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202509_created_at_idx;


--
-- TOC entry 5167 (class 0 OID 0)
-- Name: user_logs_y202509_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202509_pkey;


--
-- TOC entry 5168 (class 0 OID 0)
-- Name: user_logs_y202509_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202509_user_id_idx;


--
-- TOC entry 5206 (class 2620 OID 98765)
-- Name: courses after_course_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_course_insert AFTER INSERT ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_operation();


--
-- TOC entry 5207 (class 2620 OID 98766)
-- Name: courses after_course_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_course_update AFTER UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_operation();


--
-- TOC entry 5210 (class 2620 OID 98767)
-- Name: users after_role_changed; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_role_changed AFTER UPDATE OF role_id ON public.users FOR EACH ROW EXECUTE FUNCTION public.role_changed_trigger();


--
-- TOC entry 5208 (class 2620 OID 98768)
-- Name: courses before_course_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_course_delete BEFORE DELETE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_delete_operation();


--
-- TOC entry 5211 (class 2620 OID 98769)
-- Name: users before_user_deleted; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_user_deleted BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_deleted_trigger();


--
-- TOC entry 5209 (class 2620 OID 98770)
-- Name: courses trg_after_course_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_after_course_insert AFTER INSERT ON public.courses FOR EACH ROW EXECUTE FUNCTION public.fn_notify_new_course();


--
-- TOC entry 5169 (class 2606 OID 98771)
-- Name: answer_attributes answer_attributes_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_answer_id_fkey FOREIGN KEY (answer_id) REFERENCES public.test_block_answers(id) ON DELETE CASCADE;


--
-- TOC entry 5170 (class 2606 OID 98776)
-- Name: certificates certificates_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5171 (class 2606 OID 98781)
-- Name: certificates certificates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5172 (class 2606 OID 98786)
-- Name: chapter_block_attributes chapter_block_attributes_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.chapter_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5173 (class 2606 OID 98791)
-- Name: chapter_blocks chapter_blocks_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5174 (class 2606 OID 98796)
-- Name: chapters chapters_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5175 (class 2606 OID 98801)
-- Name: course_answers course_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.course_questions(id) ON DELETE CASCADE;


--
-- TOC entry 5176 (class 2606 OID 98806)
-- Name: course_answers course_answers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5180 (class 2606 OID 98811)
-- Name: course_questions course_questions_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE SET NULL;


--
-- TOC entry 5181 (class 2606 OID 98816)
-- Name: course_questions course_questions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5182 (class 2606 OID 98821)
-- Name: courses courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5178 (class 2606 OID 98826)
-- Name: course_notes fk_course; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_notes
    ADD CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES public.courses(id);


--
-- TOC entry 5177 (class 2606 OID 98831)
-- Name: course_logs fk_course_logs_users; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.course_logs
    ADD CONSTRAINT fk_course_logs_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5203 (class 2606 OID 98848)
-- Name: users fk_role_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_role_id FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE SET NULL;


--
-- TOC entry 5179 (class 2606 OID 98853)
-- Name: course_notes fk_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_notes
    ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5196 (class 2606 OID 98858)
-- Name: user_logs fk_user_logs_changed_by_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.user_logs
    ADD CONSTRAINT fk_user_logs_changed_by_user_id FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id);


--
-- TOC entry 5197 (class 2606 OID 98878)
-- Name: user_logs fk_user_logs_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.user_logs
    ADD CONSTRAINT fk_user_logs_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5183 (class 2606 OID 98898)
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5184 (class 2606 OID 98903)
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- TOC entry 5185 (class 2606 OID 98908)
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- TOC entry 5186 (class 2606 OID 98913)
-- Name: test_block_answers test_block_answers_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers
    ADD CONSTRAINT test_block_answers_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5187 (class 2606 OID 98918)
-- Name: test_block_attributes test_block_attributes_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5188 (class 2606 OID 98923)
-- Name: test_blocks test_blocks_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks
    ADD CONSTRAINT test_blocks_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 5189 (class 2606 OID 98928)
-- Name: tests tests_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5190 (class 2606 OID 98933)
-- Name: tests tests_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5191 (class 2606 OID 98938)
-- Name: tests tests_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5192 (class 2606 OID 98943)
-- Name: user_chapter user_chapter_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5193 (class 2606 OID 98948)
-- Name: user_chapter user_chapter_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5194 (class 2606 OID 98953)
-- Name: user_courses user_courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5195 (class 2606 OID 98958)
-- Name: user_courses user_courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5198 (class 2606 OID 98963)
-- Name: user_test_answers user_test_answers_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.user_test_attempts(id) ON DELETE CASCADE;


--
-- TOC entry 5199 (class 2606 OID 98968)
-- Name: user_test_answers user_test_answers_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5200 (class 2606 OID 98973)
-- Name: user_test_answers user_test_answers_selected_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_selected_answer_id_fkey FOREIGN KEY (selected_answer_id) REFERENCES public.test_block_answers(id) ON DELETE SET NULL;


--
-- TOC entry 5201 (class 2606 OID 98978)
-- Name: user_test_attempts user_test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 5202 (class 2606 OID 98983)
-- Name: user_test_attempts user_test_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5204 (class 2606 OID 98988)
-- Name: users users_id_verificationtoken_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_verificationtoken_fkey FOREIGN KEY (verification_token_id) REFERENCES public.verification_tokens(id);


--
-- TOC entry 5205 (class 2606 OID 98993)
-- Name: verification_tokens verificationtokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5422 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2025-06-10 10:06:43

--
-- PostgreSQL database dump complete
--

