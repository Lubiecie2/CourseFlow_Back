--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-05-29 15:51:25

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
-- TOC entry 5368 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- TOC entry 274 (class 1255 OID 65563)
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
-- TOC entry 289 (class 1255 OID 65564)
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
-- TOC entry 290 (class 1255 OID 65565)
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
-- TOC entry 291 (class 1255 OID 65566)
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
-- TOC entry 292 (class 1255 OID 65567)
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
-- TOC entry 293 (class 1255 OID 65568)
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
-- TOC entry 294 (class 1255 OID 65569)
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
-- TOC entry 295 (class 1255 OID 65570)
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
-- TOC entry 296 (class 1255 OID 65571)
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
-- TOC entry 273 (class 1255 OID 65572)
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
-- TOC entry 275 (class 1255 OID 65573)
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
-- TOC entry 276 (class 1255 OID 65574)
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
-- TOC entry 277 (class 1255 OID 65575)
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
-- TOC entry 217 (class 1259 OID 65576)
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
-- TOC entry 218 (class 1259 OID 65583)
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
-- TOC entry 219 (class 1259 OID 65588)
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
-- TOC entry 5370 (class 0 OID 0)
-- Dependencies: 219
-- Name: answer_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.answer_attributes_id_seq OWNED BY public.answer_attributes.id;


--
-- TOC entry 220 (class 1259 OID 65589)
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
-- TOC entry 221 (class 1259 OID 65596)
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
-- TOC entry 5371 (class 0 OID 0)
-- Dependencies: 221
-- Name: certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificates_id_seq OWNED BY public.certificates.id;


--
-- TOC entry 222 (class 1259 OID 65597)
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
-- TOC entry 223 (class 1259 OID 65602)
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
-- TOC entry 5372 (class 0 OID 0)
-- Dependencies: 223
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_block_attributes_id_seq OWNED BY public.chapter_block_attributes.id;


--
-- TOC entry 224 (class 1259 OID 65603)
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
-- TOC entry 225 (class 1259 OID 65611)
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
-- TOC entry 5373 (class 0 OID 0)
-- Dependencies: 225
-- Name: chapter_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_blocks_id_seq OWNED BY public.chapter_blocks.id;


--
-- TOC entry 226 (class 1259 OID 65612)
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
-- TOC entry 227 (class 1259 OID 65619)
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
-- TOC entry 5374 (class 0 OID 0)
-- Dependencies: 227
-- Name: chapters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapters_id_seq OWNED BY public.chapters.id;


--
-- TOC entry 228 (class 1259 OID 65620)
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
-- TOC entry 229 (class 1259 OID 65628)
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
-- TOC entry 5375 (class 0 OID 0)
-- Dependencies: 229
-- Name: course_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_answers_id_seq OWNED BY public.course_answers.id;


--
-- TOC entry 230 (class 1259 OID 65629)
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
-- TOC entry 231 (class 1259 OID 65633)
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
-- TOC entry 5376 (class 0 OID 0)
-- Dependencies: 231
-- Name: course_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_logs_id_seq OWNED BY public.course_logs.id;


--
-- TOC entry 232 (class 1259 OID 65634)
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
-- TOC entry 233 (class 1259 OID 65641)
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
-- TOC entry 234 (class 1259 OID 65648)
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
-- TOC entry 235 (class 1259 OID 65655)
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
-- TOC entry 236 (class 1259 OID 65663)
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
-- TOC entry 5377 (class 0 OID 0)
-- Dependencies: 236
-- Name: course_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_questions_id_seq OWNED BY public.course_questions.id;


--
-- TOC entry 237 (class 1259 OID 65664)
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
-- TOC entry 238 (class 1259 OID 65672)
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
-- TOC entry 5378 (class 0 OID 0)
-- Dependencies: 238
-- Name: courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.courses_id_seq OWNED BY public.courses.id;


--
-- TOC entry 239 (class 1259 OID 65673)
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
-- TOC entry 240 (class 1259 OID 65680)
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
-- TOC entry 5379 (class 0 OID 0)
-- Dependencies: 240
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- TOC entry 241 (class 1259 OID 65681)
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
-- TOC entry 242 (class 1259 OID 65688)
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
-- TOC entry 5380 (class 0 OID 0)
-- Dependencies: 242
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- TOC entry 243 (class 1259 OID 65689)
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
-- TOC entry 244 (class 1259 OID 65694)
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
-- TOC entry 245 (class 1259 OID 65701)
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
-- TOC entry 5381 (class 0 OID 0)
-- Dependencies: 245
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- TOC entry 246 (class 1259 OID 65702)
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
-- TOC entry 247 (class 1259 OID 65709)
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
-- TOC entry 5382 (class 0 OID 0)
-- Dependencies: 247
-- Name: test_block_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_block_answers_id_seq OWNED BY public.test_block_answers.id;


--
-- TOC entry 248 (class 1259 OID 65710)
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
-- TOC entry 249 (class 1259 OID 65715)
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
-- TOC entry 5383 (class 0 OID 0)
-- Dependencies: 249
-- Name: test_block_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_block_attributes_id_seq OWNED BY public.test_block_attributes.id;


--
-- TOC entry 250 (class 1259 OID 65716)
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
-- TOC entry 251 (class 1259 OID 65725)
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
-- TOC entry 5384 (class 0 OID 0)
-- Dependencies: 251
-- Name: test_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_blocks_id_seq OWNED BY public.test_blocks.id;


--
-- TOC entry 252 (class 1259 OID 65726)
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
-- TOC entry 253 (class 1259 OID 65736)
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
-- TOC entry 5385 (class 0 OID 0)
-- Dependencies: 253
-- Name: tests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tests_id_seq OWNED BY public.tests.id;


--
-- TOC entry 254 (class 1259 OID 65737)
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
-- TOC entry 255 (class 1259 OID 65742)
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
-- TOC entry 5386 (class 0 OID 0)
-- Dependencies: 255
-- Name: user_chapter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_chapter_id_seq OWNED BY public.user_chapter.id;


--
-- TOC entry 256 (class 1259 OID 65743)
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
-- TOC entry 257 (class 1259 OID 65749)
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
-- TOC entry 5387 (class 0 OID 0)
-- Dependencies: 257
-- Name: user_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_courses_id_seq OWNED BY public.user_courses.id;


--
-- TOC entry 258 (class 1259 OID 65750)
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
-- TOC entry 259 (class 1259 OID 65754)
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
-- TOC entry 5388 (class 0 OID 0)
-- Dependencies: 259
-- Name: user_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_logs_id_seq OWNED BY public.user_logs.id;


--
-- TOC entry 260 (class 1259 OID 65755)
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
-- TOC entry 261 (class 1259 OID 65762)
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
-- TOC entry 262 (class 1259 OID 65769)
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
-- TOC entry 263 (class 1259 OID 65776)
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
-- TOC entry 264 (class 1259 OID 65783)
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
-- TOC entry 265 (class 1259 OID 65790)
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
-- TOC entry 266 (class 1259 OID 65797)
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
-- TOC entry 5389 (class 0 OID 0)
-- Dependencies: 266
-- Name: user_test_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_test_answers_id_seq OWNED BY public.user_test_answers.id;


--
-- TOC entry 267 (class 1259 OID 65798)
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
-- TOC entry 268 (class 1259 OID 65806)
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
-- TOC entry 5390 (class 0 OID 0)
-- Dependencies: 268
-- Name: user_test_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_test_attempts_id_seq OWNED BY public.user_test_attempts.id;


--
-- TOC entry 269 (class 1259 OID 65807)
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
    first_login boolean DEFAULT true
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 65817)
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
-- TOC entry 5391 (class 0 OID 0)
-- Dependencies: 270
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 271 (class 1259 OID 65818)
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
-- TOC entry 272 (class 1259 OID 65822)
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
-- TOC entry 5392 (class 0 OID 0)
-- Dependencies: 272
-- Name: verification_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_tokens_id_seq OWNED BY public.verification_tokens.id;


--
-- TOC entry 4858 (class 0 OID 0)
-- Name: course_logs_y202505; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202505 FOR VALUES FROM ('2025-05-01 00:00:00') TO ('2025-06-01 00:00:00');


--
-- TOC entry 4859 (class 0 OID 0)
-- Name: course_logs_y202506; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202506 FOR VALUES FROM ('2025-06-01 00:00:00') TO ('2025-07-01 00:00:00');


--
-- TOC entry 4860 (class 0 OID 0)
-- Name: course_logs_y202507; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ATTACH PARTITION public.course_logs_y202507 FOR VALUES FROM ('2025-07-01 00:00:00') TO ('2025-08-01 00:00:00');


--
-- TOC entry 4861 (class 0 OID 0)
-- Name: user_logs_y202505; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202505 FOR VALUES FROM ('2025-05-01 00:00:00') TO ('2025-06-01 00:00:00');


--
-- TOC entry 4862 (class 0 OID 0)
-- Name: user_logs_y202506; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202506 FOR VALUES FROM ('2025-06-01 00:00:00') TO ('2025-07-01 00:00:00');


--
-- TOC entry 4863 (class 0 OID 0)
-- Name: user_logs_y202507; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202507 FOR VALUES FROM ('2025-07-01 00:00:00') TO ('2025-08-01 00:00:00');


--
-- TOC entry 4864 (class 0 OID 0)
-- Name: user_logs_y202508; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202508 FOR VALUES FROM ('2025-08-01 00:00:00') TO ('2025-09-01 00:00:00');


--
-- TOC entry 4865 (class 0 OID 0)
-- Name: user_logs_y202509; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ATTACH PARTITION public.user_logs_y202509 FOR VALUES FROM ('2025-09-01 00:00:00') TO ('2025-10-01 00:00:00');


--
-- TOC entry 4868 (class 2604 OID 65823)
-- Name: answer_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes ALTER COLUMN id SET DEFAULT nextval('public.answer_attributes_id_seq'::regclass);


--
-- TOC entry 4869 (class 2604 OID 65824)
-- Name: certificates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates ALTER COLUMN id SET DEFAULT nextval('public.certificates_id_seq'::regclass);


--
-- TOC entry 4872 (class 2604 OID 65825)
-- Name: chapter_block_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes ALTER COLUMN id SET DEFAULT nextval('public.chapter_block_attributes_id_seq'::regclass);


--
-- TOC entry 4873 (class 2604 OID 65826)
-- Name: chapter_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks ALTER COLUMN id SET DEFAULT nextval('public.chapter_blocks_id_seq'::regclass);


--
-- TOC entry 4877 (class 2604 OID 65827)
-- Name: chapters id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters ALTER COLUMN id SET DEFAULT nextval('public.chapters_id_seq'::regclass);


--
-- TOC entry 4880 (class 2604 OID 65828)
-- Name: course_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers ALTER COLUMN id SET DEFAULT nextval('public.course_answers_id_seq'::regclass);


--
-- TOC entry 4884 (class 2604 OID 65829)
-- Name: course_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs ALTER COLUMN id SET DEFAULT nextval('public.course_logs_id_seq'::regclass);


--
-- TOC entry 4892 (class 2604 OID 65830)
-- Name: course_questions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions ALTER COLUMN id SET DEFAULT nextval('public.course_questions_id_seq'::regclass);


--
-- TOC entry 4896 (class 2604 OID 65831)
-- Name: courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses ALTER COLUMN id SET DEFAULT nextval('public.courses_id_seq'::regclass);


--
-- TOC entry 4900 (class 2604 OID 65832)
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- TOC entry 4903 (class 2604 OID 65833)
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- TOC entry 4908 (class 2604 OID 65834)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 4911 (class 2604 OID 65835)
-- Name: test_block_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers ALTER COLUMN id SET DEFAULT nextval('public.test_block_answers_id_seq'::regclass);


--
-- TOC entry 4914 (class 2604 OID 65836)
-- Name: test_block_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes ALTER COLUMN id SET DEFAULT nextval('public.test_block_attributes_id_seq'::regclass);


--
-- TOC entry 4915 (class 2604 OID 65837)
-- Name: test_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks ALTER COLUMN id SET DEFAULT nextval('public.test_blocks_id_seq'::regclass);


--
-- TOC entry 4920 (class 2604 OID 65838)
-- Name: tests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests ALTER COLUMN id SET DEFAULT nextval('public.tests_id_seq'::regclass);


--
-- TOC entry 4926 (class 2604 OID 65839)
-- Name: user_chapter id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter ALTER COLUMN id SET DEFAULT nextval('public.user_chapter_id_seq'::regclass);


--
-- TOC entry 4929 (class 2604 OID 65840)
-- Name: user_courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses ALTER COLUMN id SET DEFAULT nextval('public.user_courses_id_seq'::regclass);


--
-- TOC entry 4933 (class 2604 OID 65841)
-- Name: user_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs ALTER COLUMN id SET DEFAULT nextval('public.user_logs_id_seq'::regclass);


--
-- TOC entry 4945 (class 2604 OID 65842)
-- Name: user_test_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers ALTER COLUMN id SET DEFAULT nextval('public.user_test_answers_id_seq'::regclass);


--
-- TOC entry 4948 (class 2604 OID 65843)
-- Name: user_test_attempts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts ALTER COLUMN id SET DEFAULT nextval('public.user_test_attempts_id_seq'::regclass);


--
-- TOC entry 4954 (class 2604 OID 65844)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4960 (class 2604 OID 65845)
-- Name: verification_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens ALTER COLUMN id SET DEFAULT nextval('public.verification_tokens_id_seq'::regclass);


--
-- TOC entry 5309 (class 0 OID 65576)
-- Dependencies: 217
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
cc8802ab-4ab7-4a55-9878-b5bb0f0013ac	eb03430e2cb43c27ddd6f5f881c349e32ddfc9e63234f316bb90527d1b35c187	2025-04-06 19:58:41.165818+02	20250406175841_migracja1	\N	\N	2025-04-06 19:58:41.082249+02	1
\.


--
-- TOC entry 5310 (class 0 OID 65583)
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
\.


--
-- TOC entry 5312 (class 0 OID 65589)
-- Dependencies: 220
-- Data for Name: certificates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificates (id, user_id, course_id, certificate_code, issued_at, pdf_url, status) FROM stdin;
27	75	1	CF-DF303494	2025-05-29 12:57:37.344	/uploads/certificates/CF-DF303494.pdf	issued
\.


--
-- TOC entry 5314 (class 0 OID 65597)
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
109282	47650	content	 1. Wprowadzenie do łączenia tabel
109283	47650	format	,text-center,text-2xl
109284	47651	content	W relacyjnych bazach danych dane są zwykle przechowywane w wielu powiązanych ze sobą tabelach. Aby skutecznie analizować i zestawiać dane z różnych tabel, konieczne jest ich łączenie za pomocą zapytań SQL. Jednym z najczęściej wykorzystywanych typów łączeń jest INNER JOIN.
109285	47651	format	text-lg
109286	47652	content	SELECT kolumny\nFROM tabela1\nINNER JOIN tabela2\nON tabela1.klucz = tabela2.klucz;
109287	47652	language	javascript
109288	47652	caption	Składnia 
109289	47652	showLineNumbers	true
109290	47652	format	
109291	47653	content	\n
109292	47653	format	,text-lg
109293	47654	type	ordered
109294	47654	format	text-2xl,italic,underline,text-center,text-red
109295	47654	items	QWE,ouoh
109296	47655	content	knhljkhlkhl
109297	47655	format	,text-xl,text-orange
109298	47656	content	Lorem ipsum
109299	47656	format	,text-green
109300	47657	content	QWEQWEQWEQWEQW
109301	47657	format	font-bold,text-lg,text-orange
109302	47658	content	asdasdasdasdasd
109303	47658	format	font-bold,text-xs,underline,italic,text-green
109304	47659	items	Jeden,Dwy
109305	47659	type	ordered
109306	47659	format	,text-green,text-2xl
109307	47660	content	ASD
109308	47660	format	text-sm,font-bold
109309	47661	content	NOwy asd
109310	47661	format	font-bold,italic,underline
109311	47662	content	Paragraf
109312	47662	format	font-bold,italic,underline
109313	47663	content	Par2
109314	47663	format	font-bold
109315	47664	content	jhb
109316	47665	content	jhb
109317	47666	content	jhgjghj
109318	47666	format	text-red
109319	47667	content	iqwheikqwneoi;hwqn
109320	47668	content	ergwererg
109321	47668	format	font-bold,italic
109322	47669	content	jhghgj
109323	47669	format	
109324	47670	content	asdsaddsadsadsa
109325	47670	format	italic
109326	47671	content	asdsaddsadsadsa
109327	47671	format	italic
109328	47672	src	http://localhost:4000/uploads/image-1745325157490-688331706.jpg
109329	47672	alt	lfndtoirttvx.jpg
109330	47672	caption	
109331	47672	format	image-sm
109332	47672	content	
109333	47673	src	http://localhost:4000/uploads/video-1745330323185-921622002.mp4
109334	47673	caption	
109335	47673	format	video-md
109336	47674	src	http://localhost:4000/uploads/video-1745869505030-873262995.mp4
109337	47674	caption	
109338	47674	format	video-md,text-center
109339	47675	content	dsdasd
109340	47675	format	
109341	47676	content	dsdasd
109342	47676	format	
109343	47677	language	html
109344	47677	caption	Procedurka2115
109345	47677	showLineNumbers	false
109346	47677	format	
109347	47677	content	DELIMITER //\nsadasdsad\nCREATE PROCEDURE promote_if_ready(IN id INT)\nBEGIN\n\tDECLARE v_avg_salary DECIMAL(10,2);\n\tDECLARE v_emp_staz INT;\n\tDECLARE v_emp_hire_date DATE;\n\tDECLARE v_emp_salary DECIMAL(10,2);\n\tDECLARE v_emp_title VARCHAR(30);\t\t\n\n\tSELECT AVG(salary) INTO v_avg_salary FROM salaries;\n\tSELECT salary INTO v_emp_salary FROM salaries WHERE emp_no = id AND to_date = '9999-01-01';\n\tSELECT hire_date INTO v_avg_hire_date FROM employees WHERE emp_no = id;\n\tSELECT title INTO v_emp_title FROM titles WHERE emp_no =id;\t\n\n\tSET v_emp_staz = TIMESTAMPDIFF(YEAR,v_emp_hire_date,CURDATE());\n\n\tIF v_emp_staz >= 5 AND v_emp_title != 'Manager' THEN\n\t\tUPDATE titles SET to_date = CURDATE() WHERE emp_no = id;\n\t\tINSERT INTO titles (emp_no,title,from_date,to_date) VALUES (id,'Manager',CURDATE(),'9999-01-01');\n\tEND IF;\nEND //
\.


--
-- TOC entry 5316 (class 0 OID 65603)
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
47650	31	text	\N	0	2025-05-28 17:13:28.836	2025-05-28 17:13:28.836
47651	31	text	\N	1	2025-05-28 17:13:28.838	2025-05-28 17:13:28.838
47652	31	code	\N	2	2025-05-28 17:13:28.841	2025-05-28 17:13:28.841
47653	31	heading	\N	3	2025-05-28 17:13:28.843	2025-05-28 17:13:28.843
47654	31	list	\N	4	2025-05-28 17:13:28.845	2025-05-28 17:13:28.845
47655	31	text	\N	5	2025-05-28 17:13:28.847	2025-05-28 17:13:28.847
47656	31	heading	\N	6	2025-05-28 17:13:28.849	2025-05-28 17:13:28.849
47657	31	heading	\N	7	2025-05-28 17:13:28.851	2025-05-28 17:13:28.851
47658	31	text	\N	8	2025-05-28 17:13:28.852	2025-05-28 17:13:28.852
47659	31	list	\N	9	2025-05-28 17:13:28.854	2025-05-28 17:13:28.854
47660	31	heading	\N	10	2025-05-28 17:13:28.856	2025-05-28 17:13:28.856
47661	31	text	\N	11	2025-05-28 17:13:28.857	2025-05-28 17:13:28.857
47662	31	text	\N	12	2025-05-28 17:13:28.859	2025-05-28 17:13:28.859
47663	31	text	\N	13	2025-05-28 17:13:28.86	2025-05-28 17:13:28.86
47664	31	text	\N	14	2025-05-28 17:13:28.862	2025-05-28 17:13:28.862
47665	31	text	\N	15	2025-05-28 17:13:28.863	2025-05-28 17:13:28.863
47666	31	text	\N	16	2025-05-28 17:13:28.865	2025-05-28 17:13:28.865
47667	31	text	\N	17	2025-05-28 17:13:28.867	2025-05-28 17:13:28.867
47668	31	text	\N	18	2025-05-28 17:13:28.869	2025-05-28 17:13:28.869
47669	31	text	\N	19	2025-05-28 17:13:28.87	2025-05-28 17:13:28.87
47670	31	text	\N	20	2025-05-28 17:13:28.872	2025-05-28 17:13:28.872
47671	31	text	\N	21	2025-05-28 17:13:28.874	2025-05-28 17:13:28.874
47672	31	image	\N	22	2025-05-28 17:13:28.875	2025-05-28 17:13:28.875
47673	31	video	\N	23	2025-05-28 17:13:28.877	2025-05-28 17:13:28.877
47674	31	video	\N	24	2025-05-28 17:13:28.879	2025-05-28 17:13:28.879
47675	31	text	\N	25	2025-05-28 17:13:28.88	2025-05-28 17:13:28.88
47676	31	text	\N	26	2025-05-28 17:13:28.882	2025-05-28 17:13:28.882
47677	31	code	\N	27	2025-05-28 17:13:28.883	2025-05-28 17:13:28.883
\.


--
-- TOC entry 5318 (class 0 OID 65612)
-- Dependencies: 226
-- Data for Name: chapters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapters (id, course_id, title, wysiwyg_code, created_at, updated_at) FROM stdin;
38	1	Rozdział 3	\N	2025-04-23 09:45:37.978	2025-04-23 09:45:37.978
29	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:48:27.677	2025-04-10 09:48:27.696
27	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:41:00.426	2025-04-10 09:41:00.426
28	4	Qwerty	\N	2025-04-10 09:47:01.831	2025-04-10 10:21:35.281
31	1	Złączenia: INNER JOIN	\N	2025-04-10 14:21:23.339	2025-05-28 17:13:28.885
\.


--
-- TOC entry 5320 (class 0 OID 65620)
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
48	Tak zgadza się !!!\n	6	12	f	2025-05-19 23:37:48.973686	2025-05-19 23:37:48.973686
\.


--
-- TOC entry 5323 (class 0 OID 65634)
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
\.


--
-- TOC entry 5324 (class 0 OID 65641)
-- Dependencies: 233
-- Data for Name: course_logs_y202506; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202506 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
\.


--
-- TOC entry 5325 (class 0 OID 65648)
-- Dependencies: 234
-- Data for Name: course_logs_y202507; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_logs_y202507 (id, course_id, user_id, action_type, old_value, new_value, course_title, action_description, created_at) FROM stdin;
\.


--
-- TOC entry 5326 (class 0 OID 65655)
-- Dependencies: 235
-- Data for Name: course_questions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_questions (id, title, content, user_id, course_id, created_at, updated_at, views) FROM stdin;
2	Jak działa mechanizm dziedziczenia w JavaScript?	Czy ktoś może wyjaśnić, jak działa dziedziczenie prototypowe w JavaScript i czym różni się od dziedziczenia klasowego znanego z innych języków?	6	\N	2025-05-15 15:23:05.054	2025-05-15 15:23:05.054	0
5	Dlaczego niebo jest niebieskie	Chce wiedzieć dlaczego niebo jest niebieskie	6	1	2025-05-15 17:43:54.227	2025-05-15 17:43:54.227	0
3	Jak dodać nowy element do tablicy w JavaScript?	Próbuję dodać nowy element na końcu tablicy w JavaScript. Jaką metodę powinienem użyć? Czy istnieje różnica między metodami push i unshift?	6	4	2025-05-15 15:43:24.082	2025-05-15 15:43:24.082	3
4	asd	asd	6	\N	2025-05-15 16:46:33.189	2025-05-15 16:46:33.189	1
7	qwe	qwe	6	1	2025-05-15 20:10:02.795	2025-05-15 20:10:02.795	11
6	asd	asd	6	1	2025-05-15 20:07:54.616	2025-05-15 20:07:54.616	11
8	Siema	Siema	6	\N	2025-05-15 21:05:18.7	2025-05-15 21:05:18.7	141
10	Siema mam pytanie	to jest moje pytanie	6	\N	2025-05-18 14:58:58.961	2025-05-18 14:58:58.961	7
15	qwerty	qwerty	6	\N	2025-05-20 10:04:08.638	2025-05-20 10:04:08.638	10
14	asd	asd	6	\N	2025-05-20 10:03:35.347	2025-05-20 10:03:35.347	8
12	Siemanko	Siemanko	6	4	2025-05-19 20:21:32.553	2025-05-19 20:21:32.553	38
11	Siemanko mam pytanie	A pytanie to.................	6	\N	2025-05-19 08:23:24.149	2025-05-19 08:23:24.149	2
17	qweqwe	qweqweqw	6	\N	2025-05-20 10:52:16.55	2025-05-20 10:52:16.55	7
\.


--
-- TOC entry 5328 (class 0 OID 65664)
-- Dependencies: 237
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.courses (id, user_id, title, short_description, course_image, category, is_published, created_at, updated_at) FROM stdin;
4	6	Januszex	Jak zostać januszem biznesu. Kurs skrócony. 	image-1744113137775-877468046.jpg	biznes	f	2025-04-08 11:52:17.883	2025-04-08 11:52:17.883
27	6	Jakiś tam kurs	asdasd	\N	design	f	2025-05-19 21:17:13.848	2025-05-19 21:17:13.848
1	6	kurs pokazowy	Tu jest kurs pokazowy 	image-1743964170219-229743977.jpg	programowanie	f	2025-04-06 18:29:30.271	2025-05-28 09:58:09.15
\.


--
-- TOC entry 5330 (class 0 OID 65673)
-- Dependencies: 239
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
797	75	Witaj w CourseFlow!	Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!	WELCOME	\N	2025-05-29 14:56:35.527+02	f
\.


--
-- TOC entry 5332 (class 0 OID 65681)
-- Dependencies: 241
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.permissions (id, name, description, created_at, updated_at) FROM stdin;
4	PANEL_SHOW_USERS_LIST	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
6	PANEL_EDIT_USERS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
7	PANEL_CREATE_ROLE	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
8	PANEL_SHOW_TESTS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
9	PANEL_SHOW_COURSES	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
10	PANEL_SHOW_ADMIN_PANEL	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
11	PANEL_SHOW_USERS	\N	2025-04-06 20:26:26.094472	2025-04-06 20:26:26.094472
\.


--
-- TOC entry 5334 (class 0 OID 65689)
-- Dependencies: 243
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.role_permissions (role_id, permission_id, created_at, updated_at) FROM stdin;
1	4	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	6	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	7	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	8	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	9	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	10	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
1	11	2025-04-06 20:28:29.821322	2025-04-06 20:28:29.821322
3	4	2025-05-11 21:31:24.051647	2025-05-11 21:31:24.051647
3	9	2025-05-11 21:31:24.099676	2025-05-11 21:31:24.099676
3	10	2025-05-11 21:31:24.213877	2025-05-11 21:31:24.213877
7	6	2025-05-11 21:33:17.668718	2025-05-11 21:33:17.668718
7	10	2025-05-11 21:33:17.713529	2025-05-11 21:33:17.713529
7	9	2025-05-11 21:33:17.814409	2025-05-11 21:33:17.814409
\.


--
-- TOC entry 5335 (class 0 OID 65694)
-- Dependencies: 244
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name, description, created_at, updated_at) FROM stdin;
2	user	\N	2025-04-06 20:18:11.248218	2025-04-06 20:18:11.248218
1	admin	\N	2025-04-06 20:20:53.067592	2025-04-06 20:20:53.067592
3	Moderator kursów 	\N	2025-04-06 22:56:16.168522	2025-04-06 22:56:16.168522
7	Mini Admin	\N	2025-05-11 21:33:17.667275	2025-05-11 21:33:17.667275
\.


--
-- TOC entry 5337 (class 0 OID 65702)
-- Dependencies: 246
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
\.


--
-- TOC entry 5339 (class 0 OID 65710)
-- Dependencies: 248
-- Data for Name: test_block_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_block_attributes (id, block_id, attribute_name, attribute_value) FROM stdin;
\.


--
-- TOC entry 5341 (class 0 OID 65716)
-- Dependencies: 250
-- Data for Name: test_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_blocks (id, test_id, block_type, question_text, points, sort_order, created_at, updated_at) FROM stdin;
21	6	single_choice	Ile dni ma marzec	2	1	2025-05-01 06:12:03.133	2025-05-01 06:12:03.133
22	6	single_choice	W jakim klubie gra Lewandowski (Goat)	3	2	2025-05-01 06:13:01.531	2025-05-01 06:13:01.531
20	4	single_choice	Ile to 5+5	3	0	2025-04-30 08:03:36.409	2025-05-06 10:03:07.002
23	4	text_input	Jak sie nazywa najlepszy model BMW 	3	1	2025-05-05 06:44:57.907	2025-05-06 10:03:07.002
26	4	matching	Dopasuj model auta do marki 	1	3	2025-05-06 05:41:23.907	2025-05-06 10:03:07.002
19	4	single_choice	Ile to jest 2+2	1	2	2025-04-30 08:03:21.58	2025-05-06 10:03:07.002
27	4	matching	Dopasuj Cyfry	1	4	2025-05-06 10:03:53.123	2025-05-06 10:03:53.123
13	3	single_choice	Z jakiego kraju pochodzi BMW 	1	0	2025-04-29 06:57:08.448	2025-04-29 16:26:57.701
15	3	single_choice	Dlaczego BMW jest najlepszym autem na rynku	3	1	2025-04-29 07:00:03.884	2025-04-29 16:26:57.701
28	4	true_false	Czy niebo jest niebieskie 	1	5	2025-05-12 21:19:50.954	2025-05-12 21:19:50.954
\.


--
-- TOC entry 5343 (class 0 OID 65726)
-- Dependencies: 252
-- Data for Name: tests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tests (id, chapter_id, course_id, author_id, title, description, pass_threshold, time_limit, created_at, updated_at, is_course_final) FROM stdin;
3	31	1	6	Test		60	0	2025-04-28 19:47:34.512	2025-04-28 19:47:34.512	f
4	\N	1	6	asd	ads	70	3	2025-04-29 21:22:55.778	2025-04-30 08:30:54.113	t
6	38	1	6	Rozdział 3 test		70	9	2025-05-01 06:11:33.048	2025-05-15 13:39:15.952	f
\.


--
-- TOC entry 5345 (class 0 OID 65737)
-- Dependencies: 254
-- Data for Name: user_chapter; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_chapter (id, user_id, chapter_id, is_completed, last_viewed) FROM stdin;
\.


--
-- TOC entry 5347 (class 0 OID 65743)
-- Dependencies: 256
-- Data for Name: user_courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_courses (id, user_id, course_id, progress, status, created_at) FROM stdin;
5	6	1	0.00	not_started	2025-05-02 14:59:15.956
6	6	4	0.00	not_started	2025-05-04 09:09:13.752
11	75	1	0.00	not_started	2025-05-29 12:56:44.497
\.


--
-- TOC entry 5350 (class 0 OID 65755)
-- Dependencies: 260
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
60	ROLE_CHANGED	75	6	user	Mini Admin	2025-05-28 13:09:21.187649
61	ROLE_CHANGED	75	6	Mini Admin	Moderator kursów 	2025-05-28 22:14:01.359062
\.


--
-- TOC entry 5351 (class 0 OID 65762)
-- Dependencies: 261
-- Data for Name: user_logs_y202506; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202506 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5352 (class 0 OID 65769)
-- Dependencies: 262
-- Data for Name: user_logs_y202507; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202507 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5353 (class 0 OID 65776)
-- Dependencies: 263
-- Data for Name: user_logs_y202508; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202508 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5354 (class 0 OID 65783)
-- Dependencies: 264
-- Data for Name: user_logs_y202509; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_logs_y202509 (id, action_type, user_id, changed_by_user_id, old_value, new_value, created_at) FROM stdin;
\.


--
-- TOC entry 5355 (class 0 OID 65790)
-- Dependencies: 265
-- Data for Name: user_test_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_test_answers (id, attempt_id, block_id, selected_answer_id, text_answer, json_answer, is_correct, points_awarded) FROM stdin;
75	2284	13	49	\N	\N	t	0
76	2284	15	60	\N	\N	t	0
77	2285	21	83	\N	\N	t	0
78	2285	22	85	\N	\N	t	0
79	2286	19	73	\N	\N	t	0
80	2286	20	79	\N	\N	t	0
81	2286	23	\N	seria 3 e90	\N	t	0
82	2286	26	95	{"rightItem":"M4"}	\N	t	0
83	2286	26	96	{"rightItem":"Stringer"}	\N	t	0
84	2286	26	97	{"rightItem":"RS5"}	\N	t	0
85	2286	26	98	{"rightItem":"CLA"}	\N	t	0
86	2286	27	99	{"rightItem":"1"}	\N	t	0
87	2286	27	100	{"rightItem":"2"}	\N	t	0
88	2286	27	101	{"rightItem":"3"}	\N	t	0
89	2286	28	102	\N	\N	t	0
\.


--
-- TOC entry 5357 (class 0 OID 65798)
-- Dependencies: 267
-- Data for Name: user_test_attempts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_test_attempts (id, user_id, test_id, start_time, end_time, score, max_score, passed, created_at) FROM stdin;
2284	75	3	2025-05-29 12:56:53.949	2025-05-29 12:56:53.946	4	4	t	2025-05-29 12:56:53.949
2285	75	6	2025-05-29 12:57:01.268	2025-05-29 12:57:01.267	5	5	t	2025-05-29 12:57:01.268
2286	75	4	2025-05-29 12:57:37.22	2025-05-29 12:57:37.219	10	10	t	2025-05-29 12:57:37.22
\.


--
-- TOC entry 5359 (class 0 OID 65807)
-- Dependencies: 269
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, email, password, created_at, updated_at, role_id, is_verified, verification_token_id, reset_password_token, reset_password_expires, last_password_change, first_login) FROM stdin;
6	test	test	test@testowy.pl	$2b$10$iY5PO4x5z/cWBKOSbB49UOq8nh8UA0B2ulQoNlriXrrMMsXIi7zOi	2025-04-06 20:18:40.52964	2025-04-06 20:18:40.52964	1	t	\N	\N	\N	\N	f
75	a	a	a@a.pl	$2b$10$EP.V/vbOsPFEsjNBxqYZcOtGpzE8tQyaVSIGKOAZAj1tDi3wjaCya	2025-05-28 13:08:48.586059	2025-05-28 13:08:48.586059	3	t	\N	\N	\N	\N	f
\.


--
-- TOC entry 5361 (class 0 OID 65818)
-- Dependencies: 271
-- Data for Name: verification_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_tokens (id, user_id, verification_token, created_at, expires_at) FROM stdin;
\.


--
-- TOC entry 5393 (class 0 OID 0)
-- Dependencies: 219
-- Name: answer_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.answer_attributes_id_seq', 12, true);


--
-- TOC entry 5394 (class 0 OID 0)
-- Dependencies: 221
-- Name: certificates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificates_id_seq', 27, true);


--
-- TOC entry 5395 (class 0 OID 0)
-- Dependencies: 223
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_block_attributes_id_seq', 109347, true);


--
-- TOC entry 5396 (class 0 OID 0)
-- Dependencies: 225
-- Name: chapter_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_blocks_id_seq', 47677, true);


--
-- TOC entry 5397 (class 0 OID 0)
-- Dependencies: 227
-- Name: chapters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapters_id_seq', 39, true);


--
-- TOC entry 5398 (class 0 OID 0)
-- Dependencies: 229
-- Name: course_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_answers_id_seq', 55, true);


--
-- TOC entry 5399 (class 0 OID 0)
-- Dependencies: 231
-- Name: course_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_logs_id_seq', 52, true);


--
-- TOC entry 5400 (class 0 OID 0)
-- Dependencies: 236
-- Name: course_questions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_questions_id_seq', 17, true);


--
-- TOC entry 5401 (class 0 OID 0)
-- Dependencies: 238
-- Name: courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.courses_id_seq', 29, true);


--
-- TOC entry 5402 (class 0 OID 0)
-- Dependencies: 240
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 797, true);


--
-- TOC entry 5403 (class 0 OID 0)
-- Dependencies: 242
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permissions_id_seq', 1, false);


--
-- TOC entry 5404 (class 0 OID 0)
-- Dependencies: 245
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 7, true);


--
-- TOC entry 5405 (class 0 OID 0)
-- Dependencies: 247
-- Name: test_block_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_block_answers_id_seq', 109, true);


--
-- TOC entry 5406 (class 0 OID 0)
-- Dependencies: 249
-- Name: test_block_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_block_attributes_id_seq', 4, true);


--
-- TOC entry 5407 (class 0 OID 0)
-- Dependencies: 251
-- Name: test_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_blocks_id_seq', 30, true);


--
-- TOC entry 5408 (class 0 OID 0)
-- Dependencies: 253
-- Name: tests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tests_id_seq', 9, true);


--
-- TOC entry 5409 (class 0 OID 0)
-- Dependencies: 255
-- Name: user_chapter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_chapter_id_seq', 1, false);


--
-- TOC entry 5410 (class 0 OID 0)
-- Dependencies: 257
-- Name: user_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_courses_id_seq', 11, true);


--
-- TOC entry 5411 (class 0 OID 0)
-- Dependencies: 259
-- Name: user_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_logs_id_seq', 61, true);


--
-- TOC entry 5412 (class 0 OID 0)
-- Dependencies: 266
-- Name: user_test_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_test_answers_id_seq', 89, true);


--
-- TOC entry 5413 (class 0 OID 0)
-- Dependencies: 268
-- Name: user_test_attempts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_test_attempts_id_seq', 2286, true);


--
-- TOC entry 5414 (class 0 OID 0)
-- Dependencies: 270
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 75, true);


--
-- TOC entry 5415 (class 0 OID 0)
-- Dependencies: 272
-- Name: verification_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_tokens_id_seq', 70, true);


--
-- TOC entry 4963 (class 2606 OID 65847)
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4965 (class 2606 OID 65849)
-- Name: answer_attributes answer_attributes_answer_id_attribute_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_answer_id_attribute_name_key UNIQUE (answer_id, attribute_name);


--
-- TOC entry 4967 (class 2606 OID 65851)
-- Name: answer_attributes answer_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 4971 (class 2606 OID 65853)
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);


--
-- TOC entry 4973 (class 2606 OID 65855)
-- Name: chapter_block_attributes chapter_block_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 4975 (class 2606 OID 65857)
-- Name: chapter_blocks chapter_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_pkey PRIMARY KEY (id);


--
-- TOC entry 4977 (class 2606 OID 65859)
-- Name: chapters chapters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_pkey PRIMARY KEY (id);


--
-- TOC entry 4979 (class 2606 OID 65861)
-- Name: course_answers course_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 4983 (class 2606 OID 65863)
-- Name: course_logs course_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs
    ADD CONSTRAINT course_logs_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 4990 (class 2606 OID 65865)
-- Name: course_logs_y202505 course_logs_y202505_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202505
    ADD CONSTRAINT course_logs_y202505_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 4995 (class 2606 OID 65867)
-- Name: course_logs_y202506 course_logs_y202506_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202506
    ADD CONSTRAINT course_logs_y202506_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5000 (class 2606 OID 65869)
-- Name: course_logs_y202507 course_logs_y202507_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_logs_y202507
    ADD CONSTRAINT course_logs_y202507_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5006 (class 2606 OID 65871)
-- Name: course_questions course_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_pkey PRIMARY KEY (id);


--
-- TOC entry 5009 (class 2606 OID 65873)
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- TOC entry 5012 (class 2606 OID 65875)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 5014 (class 2606 OID 65877)
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 5016 (class 2606 OID 65879)
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- TOC entry 5018 (class 2606 OID 65881)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 5021 (class 2606 OID 65883)
-- Name: test_block_answers test_block_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers
    ADD CONSTRAINT test_block_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 5024 (class 2606 OID 65885)
-- Name: test_block_attributes test_block_attributes_block_id_attribute_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_block_id_attribute_name_key UNIQUE (block_id, attribute_name);


--
-- TOC entry 5026 (class 2606 OID 65887)
-- Name: test_block_attributes test_block_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 5029 (class 2606 OID 65889)
-- Name: test_blocks test_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks
    ADD CONSTRAINT test_blocks_pkey PRIMARY KEY (id);


--
-- TOC entry 5031 (class 2606 OID 65891)
-- Name: tests tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_pkey PRIMARY KEY (id);


--
-- TOC entry 5033 (class 2606 OID 65893)
-- Name: user_chapter user_chapter_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_pkey PRIMARY KEY (id);


--
-- TOC entry 5036 (class 2606 OID 65895)
-- Name: user_courses user_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_pkey PRIMARY KEY (id);


--
-- TOC entry 5042 (class 2606 OID 65897)
-- Name: user_logs user_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs
    ADD CONSTRAINT user_logs_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5048 (class 2606 OID 65899)
-- Name: user_logs_y202505 user_logs_y202505_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202505
    ADD CONSTRAINT user_logs_y202505_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5055 (class 2606 OID 65901)
-- Name: user_logs_y202506 user_logs_y202506_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202506
    ADD CONSTRAINT user_logs_y202506_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5062 (class 2606 OID 65903)
-- Name: user_logs_y202507 user_logs_y202507_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202507
    ADD CONSTRAINT user_logs_y202507_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5069 (class 2606 OID 65905)
-- Name: user_logs_y202508 user_logs_y202508_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202508
    ADD CONSTRAINT user_logs_y202508_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5076 (class 2606 OID 65907)
-- Name: user_logs_y202509 user_logs_y202509_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_logs_y202509
    ADD CONSTRAINT user_logs_y202509_pkey PRIMARY KEY (id, created_at);


--
-- TOC entry 5081 (class 2606 OID 65909)
-- Name: user_test_answers user_test_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 5085 (class 2606 OID 65911)
-- Name: user_test_attempts user_test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 5088 (class 2606 OID 65913)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5090 (class 2606 OID 65915)
-- Name: verification_tokens verificationtokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_pkey PRIMARY KEY (id);


--
-- TOC entry 4969 (class 1259 OID 65916)
-- Name: certificates_certificate_code_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX certificates_certificate_code_key ON public.certificates USING btree (certificate_code);


--
-- TOC entry 4984 (class 1259 OID 65917)
-- Name: idx_course_logs_course_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_course_id ON ONLY public.course_logs USING btree (course_id);


--
-- TOC entry 4987 (class 1259 OID 65918)
-- Name: course_logs_y202505_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_course_id_idx ON public.course_logs_y202505 USING btree (course_id);


--
-- TOC entry 4985 (class 1259 OID 65919)
-- Name: idx_course_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_created_at ON ONLY public.course_logs USING btree (created_at);


--
-- TOC entry 4988 (class 1259 OID 65920)
-- Name: course_logs_y202505_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_created_at_idx ON public.course_logs_y202505 USING btree (created_at);


--
-- TOC entry 4986 (class 1259 OID 65921)
-- Name: idx_course_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_user_id ON ONLY public.course_logs USING btree (user_id);


--
-- TOC entry 4991 (class 1259 OID 65922)
-- Name: course_logs_y202505_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202505_user_id_idx ON public.course_logs_y202505 USING btree (user_id);


--
-- TOC entry 4992 (class 1259 OID 65923)
-- Name: course_logs_y202506_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_course_id_idx ON public.course_logs_y202506 USING btree (course_id);


--
-- TOC entry 4993 (class 1259 OID 65924)
-- Name: course_logs_y202506_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_created_at_idx ON public.course_logs_y202506 USING btree (created_at);


--
-- TOC entry 4996 (class 1259 OID 65925)
-- Name: course_logs_y202506_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202506_user_id_idx ON public.course_logs_y202506 USING btree (user_id);


--
-- TOC entry 4997 (class 1259 OID 65926)
-- Name: course_logs_y202507_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_course_id_idx ON public.course_logs_y202507 USING btree (course_id);


--
-- TOC entry 4998 (class 1259 OID 65927)
-- Name: course_logs_y202507_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_created_at_idx ON public.course_logs_y202507 USING btree (created_at);


--
-- TOC entry 5001 (class 1259 OID 65928)
-- Name: course_logs_y202507_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_logs_y202507_user_id_idx ON public.course_logs_y202507 USING btree (user_id);


--
-- TOC entry 5004 (class 1259 OID 65929)
-- Name: course_questions_course_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_questions_course_id_idx ON public.course_questions USING btree (course_id);


--
-- TOC entry 5007 (class 1259 OID 65930)
-- Name: course_questions_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX course_questions_user_id_idx ON public.course_questions USING btree (user_id);


--
-- TOC entry 4968 (class 1259 OID 65931)
-- Name: idx_answer_attributes_answer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_answer_attributes_answer_id ON public.answer_attributes USING btree (answer_id);


--
-- TOC entry 4980 (class 1259 OID 65932)
-- Name: idx_course_answers_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_answers_question_id ON public.course_answers USING btree (question_id);


--
-- TOC entry 4981 (class 1259 OID 65933)
-- Name: idx_course_answers_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_answers_user_id ON public.course_answers USING btree (user_id);


--
-- TOC entry 5002 (class 1259 OID 65934)
-- Name: idx_course_logs_y202507_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202507_action_type ON public.course_logs_y202507 USING btree (action_type, created_at);


--
-- TOC entry 5003 (class 1259 OID 65935)
-- Name: idx_course_logs_y202507_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_course_logs_y202507_user_id ON public.course_logs_y202507 USING btree (user_id, created_at);


--
-- TOC entry 5010 (class 1259 OID 65936)
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- TOC entry 5019 (class 1259 OID 65937)
-- Name: idx_test_block_answers_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_block_answers_block_id ON public.test_block_answers USING btree (block_id);


--
-- TOC entry 5022 (class 1259 OID 65938)
-- Name: idx_test_block_attributes_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_block_attributes_block_id ON public.test_block_attributes USING btree (block_id);


--
-- TOC entry 5027 (class 1259 OID 65939)
-- Name: idx_test_blocks_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_test_blocks_test_id ON public.test_blocks USING btree (test_id);


--
-- TOC entry 5038 (class 1259 OID 65940)
-- Name: idx_user_logs_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_action_type ON ONLY public.user_logs USING btree (action_type);


--
-- TOC entry 5039 (class 1259 OID 65941)
-- Name: idx_user_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_created_at ON ONLY public.user_logs USING btree (created_at);


--
-- TOC entry 5040 (class 1259 OID 65942)
-- Name: idx_user_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_user_id ON ONLY public.user_logs USING btree (user_id);


--
-- TOC entry 5043 (class 1259 OID 65943)
-- Name: idx_user_logs_y202505_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202505_action_type ON public.user_logs_y202505 USING btree (action_type, created_at);


--
-- TOC entry 5044 (class 1259 OID 65944)
-- Name: idx_user_logs_y202505_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202505_user_id ON public.user_logs_y202505 USING btree (user_id, created_at);


--
-- TOC entry 5050 (class 1259 OID 65945)
-- Name: idx_user_logs_y202506_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202506_action_type ON public.user_logs_y202506 USING btree (action_type, created_at);


--
-- TOC entry 5051 (class 1259 OID 65946)
-- Name: idx_user_logs_y202506_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202506_user_id ON public.user_logs_y202506 USING btree (user_id, created_at);


--
-- TOC entry 5057 (class 1259 OID 65947)
-- Name: idx_user_logs_y202507_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202507_action_type ON public.user_logs_y202507 USING btree (action_type, created_at);


--
-- TOC entry 5058 (class 1259 OID 65948)
-- Name: idx_user_logs_y202507_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202507_user_id ON public.user_logs_y202507 USING btree (user_id, created_at);


--
-- TOC entry 5064 (class 1259 OID 65949)
-- Name: idx_user_logs_y202508_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202508_action_type ON public.user_logs_y202508 USING btree (action_type, created_at);


--
-- TOC entry 5065 (class 1259 OID 65950)
-- Name: idx_user_logs_y202508_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202508_user_id ON public.user_logs_y202508 USING btree (user_id, created_at);


--
-- TOC entry 5071 (class 1259 OID 65951)
-- Name: idx_user_logs_y202509_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202509_action_type ON public.user_logs_y202509 USING btree (action_type, created_at);


--
-- TOC entry 5072 (class 1259 OID 65952)
-- Name: idx_user_logs_y202509_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_logs_y202509_user_id ON public.user_logs_y202509 USING btree (user_id, created_at);


--
-- TOC entry 5078 (class 1259 OID 65953)
-- Name: idx_user_test_answers_attempt_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_answers_attempt_id ON public.user_test_answers USING btree (attempt_id);


--
-- TOC entry 5079 (class 1259 OID 65954)
-- Name: idx_user_test_answers_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_answers_block_id ON public.user_test_answers USING btree (block_id);


--
-- TOC entry 5082 (class 1259 OID 65955)
-- Name: idx_user_test_attempts_test_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_attempts_test_id ON public.user_test_attempts USING btree (test_id);


--
-- TOC entry 5083 (class 1259 OID 65956)
-- Name: idx_user_test_attempts_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_test_attempts_user_id ON public.user_test_attempts USING btree (user_id);


--
-- TOC entry 5034 (class 1259 OID 65957)
-- Name: user_chapter_user_id_chapter_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_chapter_user_id_chapter_id_key ON public.user_chapter USING btree (user_id, chapter_id);


--
-- TOC entry 5037 (class 1259 OID 65958)
-- Name: user_courses_user_id_course_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_courses_user_id_course_id_key ON public.user_courses USING btree (user_id, course_id);


--
-- TOC entry 5045 (class 1259 OID 65959)
-- Name: user_logs_y202505_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_action_type_idx ON public.user_logs_y202505 USING btree (action_type);


--
-- TOC entry 5046 (class 1259 OID 65960)
-- Name: user_logs_y202505_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_created_at_idx ON public.user_logs_y202505 USING btree (created_at);


--
-- TOC entry 5049 (class 1259 OID 65961)
-- Name: user_logs_y202505_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202505_user_id_idx ON public.user_logs_y202505 USING btree (user_id);


--
-- TOC entry 5052 (class 1259 OID 65962)
-- Name: user_logs_y202506_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_action_type_idx ON public.user_logs_y202506 USING btree (action_type);


--
-- TOC entry 5053 (class 1259 OID 65963)
-- Name: user_logs_y202506_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_created_at_idx ON public.user_logs_y202506 USING btree (created_at);


--
-- TOC entry 5056 (class 1259 OID 65964)
-- Name: user_logs_y202506_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202506_user_id_idx ON public.user_logs_y202506 USING btree (user_id);


--
-- TOC entry 5059 (class 1259 OID 65965)
-- Name: user_logs_y202507_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_action_type_idx ON public.user_logs_y202507 USING btree (action_type);


--
-- TOC entry 5060 (class 1259 OID 65966)
-- Name: user_logs_y202507_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_created_at_idx ON public.user_logs_y202507 USING btree (created_at);


--
-- TOC entry 5063 (class 1259 OID 65967)
-- Name: user_logs_y202507_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202507_user_id_idx ON public.user_logs_y202507 USING btree (user_id);


--
-- TOC entry 5066 (class 1259 OID 65968)
-- Name: user_logs_y202508_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_action_type_idx ON public.user_logs_y202508 USING btree (action_type);


--
-- TOC entry 5067 (class 1259 OID 65969)
-- Name: user_logs_y202508_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_created_at_idx ON public.user_logs_y202508 USING btree (created_at);


--
-- TOC entry 5070 (class 1259 OID 65970)
-- Name: user_logs_y202508_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202508_user_id_idx ON public.user_logs_y202508 USING btree (user_id);


--
-- TOC entry 5073 (class 1259 OID 65971)
-- Name: user_logs_y202509_action_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_action_type_idx ON public.user_logs_y202509 USING btree (action_type);


--
-- TOC entry 5074 (class 1259 OID 65972)
-- Name: user_logs_y202509_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_created_at_idx ON public.user_logs_y202509 USING btree (created_at);


--
-- TOC entry 5077 (class 1259 OID 65973)
-- Name: user_logs_y202509_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_logs_y202509_user_id_idx ON public.user_logs_y202509 USING btree (user_id);


--
-- TOC entry 5086 (class 1259 OID 65974)
-- Name: users_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);


--
-- TOC entry 5091 (class 0 OID 0)
-- Name: course_logs_y202505_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202505_course_id_idx;


--
-- TOC entry 5092 (class 0 OID 0)
-- Name: course_logs_y202505_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202505_created_at_idx;


--
-- TOC entry 5093 (class 0 OID 0)
-- Name: course_logs_y202505_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202505_pkey;


--
-- TOC entry 5094 (class 0 OID 0)
-- Name: course_logs_y202505_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202505_user_id_idx;


--
-- TOC entry 5095 (class 0 OID 0)
-- Name: course_logs_y202506_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202506_course_id_idx;


--
-- TOC entry 5096 (class 0 OID 0)
-- Name: course_logs_y202506_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202506_created_at_idx;


--
-- TOC entry 5097 (class 0 OID 0)
-- Name: course_logs_y202506_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202506_pkey;


--
-- TOC entry 5098 (class 0 OID 0)
-- Name: course_logs_y202506_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202506_user_id_idx;


--
-- TOC entry 5099 (class 0 OID 0)
-- Name: course_logs_y202507_course_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_course_id ATTACH PARTITION public.course_logs_y202507_course_id_idx;


--
-- TOC entry 5100 (class 0 OID 0)
-- Name: course_logs_y202507_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_created_at ATTACH PARTITION public.course_logs_y202507_created_at_idx;


--
-- TOC entry 5101 (class 0 OID 0)
-- Name: course_logs_y202507_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.course_logs_pkey ATTACH PARTITION public.course_logs_y202507_pkey;


--
-- TOC entry 5102 (class 0 OID 0)
-- Name: course_logs_y202507_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_course_logs_user_id ATTACH PARTITION public.course_logs_y202507_user_id_idx;


--
-- TOC entry 5103 (class 0 OID 0)
-- Name: user_logs_y202505_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202505_action_type_idx;


--
-- TOC entry 5104 (class 0 OID 0)
-- Name: user_logs_y202505_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202505_created_at_idx;


--
-- TOC entry 5105 (class 0 OID 0)
-- Name: user_logs_y202505_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202505_pkey;


--
-- TOC entry 5106 (class 0 OID 0)
-- Name: user_logs_y202505_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202505_user_id_idx;


--
-- TOC entry 5107 (class 0 OID 0)
-- Name: user_logs_y202506_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202506_action_type_idx;


--
-- TOC entry 5108 (class 0 OID 0)
-- Name: user_logs_y202506_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202506_created_at_idx;


--
-- TOC entry 5109 (class 0 OID 0)
-- Name: user_logs_y202506_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202506_pkey;


--
-- TOC entry 5110 (class 0 OID 0)
-- Name: user_logs_y202506_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202506_user_id_idx;


--
-- TOC entry 5111 (class 0 OID 0)
-- Name: user_logs_y202507_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202507_action_type_idx;


--
-- TOC entry 5112 (class 0 OID 0)
-- Name: user_logs_y202507_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202507_created_at_idx;


--
-- TOC entry 5113 (class 0 OID 0)
-- Name: user_logs_y202507_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202507_pkey;


--
-- TOC entry 5114 (class 0 OID 0)
-- Name: user_logs_y202507_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202507_user_id_idx;


--
-- TOC entry 5115 (class 0 OID 0)
-- Name: user_logs_y202508_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202508_action_type_idx;


--
-- TOC entry 5116 (class 0 OID 0)
-- Name: user_logs_y202508_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202508_created_at_idx;


--
-- TOC entry 5117 (class 0 OID 0)
-- Name: user_logs_y202508_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202508_pkey;


--
-- TOC entry 5118 (class 0 OID 0)
-- Name: user_logs_y202508_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202508_user_id_idx;


--
-- TOC entry 5119 (class 0 OID 0)
-- Name: user_logs_y202509_action_type_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_action_type ATTACH PARTITION public.user_logs_y202509_action_type_idx;


--
-- TOC entry 5120 (class 0 OID 0)
-- Name: user_logs_y202509_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_created_at ATTACH PARTITION public.user_logs_y202509_created_at_idx;


--
-- TOC entry 5121 (class 0 OID 0)
-- Name: user_logs_y202509_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.user_logs_pkey ATTACH PARTITION public.user_logs_y202509_pkey;


--
-- TOC entry 5122 (class 0 OID 0)
-- Name: user_logs_y202509_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_user_logs_user_id ATTACH PARTITION public.user_logs_y202509_user_id_idx;


--
-- TOC entry 5158 (class 2620 OID 65975)
-- Name: courses after_course_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_course_insert AFTER INSERT ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_operation();


--
-- TOC entry 5159 (class 2620 OID 65976)
-- Name: courses after_course_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_course_update AFTER UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_operation();


--
-- TOC entry 5162 (class 2620 OID 65977)
-- Name: users after_role_changed; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_role_changed AFTER UPDATE OF role_id ON public.users FOR EACH ROW EXECUTE FUNCTION public.role_changed_trigger();


--
-- TOC entry 5160 (class 2620 OID 65978)
-- Name: courses before_course_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_course_delete BEFORE DELETE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.log_course_delete_operation();


--
-- TOC entry 5163 (class 2620 OID 65979)
-- Name: users before_user_deleted; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_user_deleted BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_deleted_trigger();


--
-- TOC entry 5161 (class 2620 OID 65980)
-- Name: courses trg_after_course_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_after_course_insert AFTER INSERT ON public.courses FOR EACH ROW EXECUTE FUNCTION public.fn_notify_new_course();


--
-- TOC entry 5123 (class 2606 OID 65981)
-- Name: answer_attributes answer_attributes_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answer_attributes
    ADD CONSTRAINT answer_attributes_answer_id_fkey FOREIGN KEY (answer_id) REFERENCES public.test_block_answers(id) ON DELETE CASCADE;


--
-- TOC entry 5124 (class 2606 OID 65986)
-- Name: certificates certificates_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5125 (class 2606 OID 65991)
-- Name: certificates certificates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5126 (class 2606 OID 65996)
-- Name: chapter_block_attributes chapter_block_attributes_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.chapter_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5127 (class 2606 OID 66001)
-- Name: chapter_blocks chapter_blocks_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5128 (class 2606 OID 66006)
-- Name: chapters chapters_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5129 (class 2606 OID 66011)
-- Name: course_answers course_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.course_questions(id) ON DELETE CASCADE;


--
-- TOC entry 5130 (class 2606 OID 66016)
-- Name: course_answers course_answers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_answers
    ADD CONSTRAINT course_answers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5132 (class 2606 OID 66021)
-- Name: course_questions course_questions_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE SET NULL;


--
-- TOC entry 5133 (class 2606 OID 66026)
-- Name: course_questions course_questions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_questions
    ADD CONSTRAINT course_questions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5134 (class 2606 OID 66031)
-- Name: courses courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5131 (class 2606 OID 66050)
-- Name: course_logs fk_course_logs_users; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.course_logs
    ADD CONSTRAINT fk_course_logs_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5155 (class 2606 OID 66064)
-- Name: users fk_role_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_role_id FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE SET NULL;


--
-- TOC entry 5148 (class 2606 OID 66069)
-- Name: user_logs fk_user_logs_changed_by_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.user_logs
    ADD CONSTRAINT fk_user_logs_changed_by_user_id FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5149 (class 2606 OID 66089)
-- Name: user_logs fk_user_logs_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.user_logs
    ADD CONSTRAINT fk_user_logs_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5135 (class 2606 OID 66109)
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5136 (class 2606 OID 66114)
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- TOC entry 5137 (class 2606 OID 66119)
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- TOC entry 5138 (class 2606 OID 66124)
-- Name: test_block_answers test_block_answers_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_answers
    ADD CONSTRAINT test_block_answers_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5139 (class 2606 OID 66129)
-- Name: test_block_attributes test_block_attributes_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_block_attributes
    ADD CONSTRAINT test_block_attributes_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5140 (class 2606 OID 66134)
-- Name: test_blocks test_blocks_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_blocks
    ADD CONSTRAINT test_blocks_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 5141 (class 2606 OID 66139)
-- Name: tests tests_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5142 (class 2606 OID 66144)
-- Name: tests tests_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5143 (class 2606 OID 66149)
-- Name: tests tests_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5144 (class 2606 OID 66154)
-- Name: user_chapter user_chapter_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 5145 (class 2606 OID 66159)
-- Name: user_chapter user_chapter_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5146 (class 2606 OID 66164)
-- Name: user_courses user_courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 5147 (class 2606 OID 66169)
-- Name: user_courses user_courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5150 (class 2606 OID 66174)
-- Name: user_test_answers user_test_answers_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.user_test_attempts(id) ON DELETE CASCADE;


--
-- TOC entry 5151 (class 2606 OID 66179)
-- Name: user_test_answers user_test_answers_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.test_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 5152 (class 2606 OID 66184)
-- Name: user_test_answers user_test_answers_selected_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_answers
    ADD CONSTRAINT user_test_answers_selected_answer_id_fkey FOREIGN KEY (selected_answer_id) REFERENCES public.test_block_answers(id) ON DELETE SET NULL;


--
-- TOC entry 5153 (class 2606 OID 66189)
-- Name: user_test_attempts user_test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 5154 (class 2606 OID 66194)
-- Name: user_test_attempts user_test_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_test_attempts
    ADD CONSTRAINT user_test_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5156 (class 2606 OID 66199)
-- Name: users users_id_verificationtoken_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_verificationtoken_fkey FOREIGN KEY (verification_token_id) REFERENCES public.verification_tokens(id);


--
-- TOC entry 5157 (class 2606 OID 66204)
-- Name: verification_tokens verificationtokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5369 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2025-05-29 15:51:25

--
-- PostgreSQL database dump complete
--

