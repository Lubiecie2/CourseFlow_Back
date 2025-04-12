--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-04-10 23:44:17

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
-- TOC entry 5 (class 2615 OID 40961)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 217 (class 1259 OID 40962)
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
-- TOC entry 219 (class 1259 OID 40977)
-- Name: answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.answers (
    id integer NOT NULL,
    question_id integer,
    answer_text text NOT NULL,
    is_correct boolean DEFAULT false
);


ALTER TABLE public.answers OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 40976)
-- Name: answers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.answers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.answers_id_seq OWNER TO postgres;

--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 218
-- Name: answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.answers_id_seq OWNED BY public.answers.id;


--
-- TOC entry 221 (class 1259 OID 40987)
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
-- TOC entry 220 (class 1259 OID 40986)
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
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 220
-- Name: certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificates_id_seq OWNED BY public.certificates.id;


--
-- TOC entry 250 (class 1259 OID 41259)
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
-- TOC entry 249 (class 1259 OID 41258)
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
-- TOC entry 5082 (class 0 OID 0)
-- Dependencies: 249
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_block_attributes_id_seq OWNED BY public.chapter_block_attributes.id;


--
-- TOC entry 248 (class 1259 OID 41242)
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
-- TOC entry 247 (class 1259 OID 41241)
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
-- TOC entry 5083 (class 0 OID 0)
-- Dependencies: 247
-- Name: chapter_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapter_blocks_id_seq OWNED BY public.chapter_blocks.id;


--
-- TOC entry 223 (class 1259 OID 40998)
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
-- TOC entry 222 (class 1259 OID 40997)
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
-- TOC entry 5084 (class 0 OID 0)
-- Dependencies: 222
-- Name: chapters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chapters_id_seq OWNED BY public.chapters.id;


--
-- TOC entry 225 (class 1259 OID 41009)
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
-- TOC entry 224 (class 1259 OID 41008)
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
-- TOC entry 5085 (class 0 OID 0)
-- Dependencies: 224
-- Name: courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.courses_id_seq OWNED BY public.courses.id;


--
-- TOC entry 227 (class 1259 OID 41021)
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
-- TOC entry 226 (class 1259 OID 41020)
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
-- TOC entry 5086 (class 0 OID 0)
-- Dependencies: 226
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- TOC entry 229 (class 1259 OID 41032)
-- Name: questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.questions (
    id integer NOT NULL,
    test_id integer,
    question_text text NOT NULL
);


ALTER TABLE public.questions OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 41031)
-- Name: questions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.questions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.questions_id_seq OWNER TO postgres;

--
-- TOC entry 5087 (class 0 OID 0)
-- Dependencies: 228
-- Name: questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.questions_id_seq OWNED BY public.questions.id;


--
-- TOC entry 230 (class 1259 OID 41040)
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
-- TOC entry 232 (class 1259 OID 41048)
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
-- TOC entry 231 (class 1259 OID 41047)
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
-- TOC entry 5088 (class 0 OID 0)
-- Dependencies: 231
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- TOC entry 234 (class 1259 OID 41059)
-- Name: test_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_answers (
    id integer NOT NULL,
    attempt_id integer,
    question_id integer,
    selected_answer_id integer,
    is_correct boolean DEFAULT false
);


ALTER TABLE public.test_answers OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 41058)
-- Name: test_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_answers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_answers_id_seq OWNER TO postgres;

--
-- TOC entry 5089 (class 0 OID 0)
-- Dependencies: 233
-- Name: test_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_answers_id_seq OWNED BY public.test_answers.id;


--
-- TOC entry 236 (class 1259 OID 41067)
-- Name: test_attempts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_attempts (
    id integer NOT NULL,
    user_id integer,
    test_id integer,
    score integer DEFAULT 0,
    total_questions integer DEFAULT 0,
    passed boolean DEFAULT false,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.test_attempts OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 41066)
-- Name: test_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_attempts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.test_attempts_id_seq OWNER TO postgres;

--
-- TOC entry 5090 (class 0 OID 0)
-- Dependencies: 235
-- Name: test_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_attempts_id_seq OWNED BY public.test_attempts.id;


--
-- TOC entry 238 (class 1259 OID 41078)
-- Name: tests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tests (
    id integer NOT NULL,
    course_id integer,
    author_id integer,
    title character varying(255) NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tests OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 41077)
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
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 237
-- Name: tests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tests_id_seq OWNED BY public.tests.id;


--
-- TOC entry 240 (class 1259 OID 41087)
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
-- TOC entry 239 (class 1259 OID 41086)
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
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 239
-- Name: user_chapter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_chapter_id_seq OWNED BY public.user_chapter.id;


--
-- TOC entry 242 (class 1259 OID 41096)
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
-- TOC entry 241 (class 1259 OID 41095)
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
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 241
-- Name: user_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_courses_id_seq OWNED BY public.user_courses.id;


--
-- TOC entry 244 (class 1259 OID 41106)
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
    verification_token_id integer
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 41105)
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
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 243
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 246 (class 1259 OID 41119)
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
-- TOC entry 245 (class 1259 OID 41118)
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
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 245
-- Name: verification_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_tokens_id_seq OWNED BY public.verification_tokens.id;


--
-- TOC entry 4780 (class 2604 OID 40980)
-- Name: answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers ALTER COLUMN id SET DEFAULT nextval('public.answers_id_seq'::regclass);


--
-- TOC entry 4782 (class 2604 OID 40990)
-- Name: certificates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates ALTER COLUMN id SET DEFAULT nextval('public.certificates_id_seq'::regclass);


--
-- TOC entry 4829 (class 2604 OID 41262)
-- Name: chapter_block_attributes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes ALTER COLUMN id SET DEFAULT nextval('public.chapter_block_attributes_id_seq'::regclass);


--
-- TOC entry 4825 (class 2604 OID 41245)
-- Name: chapter_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks ALTER COLUMN id SET DEFAULT nextval('public.chapter_blocks_id_seq'::regclass);


--
-- TOC entry 4785 (class 2604 OID 41001)
-- Name: chapters id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters ALTER COLUMN id SET DEFAULT nextval('public.chapters_id_seq'::regclass);


--
-- TOC entry 4788 (class 2604 OID 41012)
-- Name: courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses ALTER COLUMN id SET DEFAULT nextval('public.courses_id_seq'::regclass);


--
-- TOC entry 4792 (class 2604 OID 41024)
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- TOC entry 4795 (class 2604 OID 41035)
-- Name: questions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions ALTER COLUMN id SET DEFAULT nextval('public.questions_id_seq'::regclass);


--
-- TOC entry 4798 (class 2604 OID 41051)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 4801 (class 2604 OID 41062)
-- Name: test_answers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_answers ALTER COLUMN id SET DEFAULT nextval('public.test_answers_id_seq'::regclass);


--
-- TOC entry 4803 (class 2604 OID 41070)
-- Name: test_attempts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts ALTER COLUMN id SET DEFAULT nextval('public.test_attempts_id_seq'::regclass);


--
-- TOC entry 4808 (class 2604 OID 41081)
-- Name: tests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests ALTER COLUMN id SET DEFAULT nextval('public.tests_id_seq'::regclass);


--
-- TOC entry 4811 (class 2604 OID 41090)
-- Name: user_chapter id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter ALTER COLUMN id SET DEFAULT nextval('public.user_chapter_id_seq'::regclass);


--
-- TOC entry 4814 (class 2604 OID 41099)
-- Name: user_courses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses ALTER COLUMN id SET DEFAULT nextval('public.user_courses_id_seq'::regclass);


--
-- TOC entry 4818 (class 2604 OID 41109)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4823 (class 2604 OID 41122)
-- Name: verification_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens ALTER COLUMN id SET DEFAULT nextval('public.verification_tokens_id_seq'::regclass);


--
-- TOC entry 5039 (class 0 OID 40962)
-- Dependencies: 217
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
cc8802ab-4ab7-4a55-9878-b5bb0f0013ac	eb03430e2cb43c27ddd6f5f881c349e32ddfc9e63234f316bb90527d1b35c187	2025-04-06 19:58:41.165818+02	20250406175841_migracja1	\N	\N	2025-04-06 19:58:41.082249+02	1
\.


--
-- TOC entry 5041 (class 0 OID 40977)
-- Dependencies: 219
-- Data for Name: answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.answers (id, question_id, answer_text, is_correct) FROM stdin;
\.


--
-- TOC entry 5043 (class 0 OID 40987)
-- Dependencies: 221
-- Data for Name: certificates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificates (id, user_id, course_id, certificate_code, issued_at, pdf_url, status) FROM stdin;
\.


--
-- TOC entry 5072 (class 0 OID 41259)
-- Dependencies: 250
-- Data for Name: chapter_block_attributes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapter_block_attributes (id, block_id, name, value) FROM stdin;
52	52	content	dddddddddddddddddddddddddddddddd
53	53	content	Jwqeeeeeeeeeeraktywnych elementów na stronach internetowych.
1519	1294	content	====================================================================================================================================
1520	1295	content	====================================================================================================================================
1521	1296	items	weqweqweqw,ttrgrtgrt,yhghty
1522	1296	type	unordered
141	141	content	treść akapitu
142	142	content	Treść
143	143	content	32422
144	144	content	Qwerty\n\n
145	145	content	Podstawy JavaScript - zaktualizowany tytuł
1523	1297	content	====================================================================================================================================
\.


--
-- TOC entry 5070 (class 0 OID 41242)
-- Dependencies: 248
-- Data for Name: chapter_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapter_blocks (id, chapter_id, type, content, sort_order, created_at, updated_at) FROM stdin;
1294	31	text	\N	0	2025-04-10 20:50:14.207	2025-04-10 20:50:14.207
1295	31	heading	\N	1	2025-04-10 20:50:14.209	2025-04-10 20:50:14.209
1296	31	list	\N	2	2025-04-10 20:50:14.213	2025-04-10 20:50:14.213
1297	31	text	\N	3	2025-04-10 20:50:14.215	2025-04-10 20:50:14.215
52	29	heading	\N	0	2025-04-10 09:48:27.685	2025-04-10 09:48:27.685
53	29	text	\N	1	2025-04-10 09:48:27.691	2025-04-10 09:48:27.691
141	28	text	\N	0	2025-04-10 10:21:35.269	2025-04-10 10:21:35.269
142	28	heading	\N	1	2025-04-10 10:21:35.272	2025-04-10 10:21:35.272
143	28	text	\N	2	2025-04-10 10:21:35.274	2025-04-10 10:21:35.274
144	28	text	\N	3	2025-04-10 10:21:35.276	2025-04-10 10:21:35.276
145	28	heading	\N	4	2025-04-10 10:21:35.279	2025-04-10 10:21:35.279
\.


--
-- TOC entry 5045 (class 0 OID 40998)
-- Dependencies: 223
-- Data for Name: chapters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chapters (id, course_id, title, wysiwyg_code, created_at, updated_at) FROM stdin;
29	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:48:27.677	2025-04-10 09:48:27.696
31	1	WYSIWYG dla ubogich aczkolwiek lekko podkręcony	\N	2025-04-10 14:21:23.339	2025-04-10 20:50:14.217
27	4	Wprowadzenie do JavaScript	\N	2025-04-10 09:41:00.426	2025-04-10 09:41:00.426
28	4	Qwerty	\N	2025-04-10 09:47:01.831	2025-04-10 10:21:35.281
\.


--
-- TOC entry 5047 (class 0 OID 41009)
-- Dependencies: 225
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.courses (id, user_id, title, short_description, course_image, category, is_published, created_at, updated_at) FROM stdin;
1	6	kurs pokazowy	Tu jest kurs pokazowy 	image-1743964170219-229743977.jpg	programowanie	f	2025-04-06 18:29:30.271	2025-04-06 18:29:30.271
2	6	****	QWOEQOWEQOWE	image-1743973191728-893771751.jpg	programowanie	f	2025-04-06 20:59:51.782	2025-04-06 20:59:51.782
3	6	kodowanko	tu będzie kursik	image-1744100545368-604256165.jpg	programowanie	f	2025-04-08 08:22:25.673	2025-04-08 08:22:25.673
4	6	Januszex	Jak zostać januszem biznesu. Kurs skrócony. 	image-1744113137775-877468046.jpg	biznes	f	2025-04-08 11:52:17.883	2025-04-08 11:52:17.883
\.


--
-- TOC entry 5049 (class 0 OID 41021)
-- Dependencies: 227
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
-- TOC entry 5051 (class 0 OID 41032)
-- Dependencies: 229
-- Data for Name: questions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.questions (id, test_id, question_text) FROM stdin;
\.


--
-- TOC entry 5052 (class 0 OID 41040)
-- Dependencies: 230
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
3	10	2025-04-06 22:57:55.968756	2025-04-06 22:57:55.968756
3	9	2025-04-06 22:57:56.022799	2025-04-06 22:57:56.022799
3	4	2025-04-06 22:57:56.026706	2025-04-06 22:57:56.026706
\.


--
-- TOC entry 5054 (class 0 OID 41048)
-- Dependencies: 232
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name, description, created_at, updated_at) FROM stdin;
2	user	\N	2025-04-06 20:18:11.248218	2025-04-06 20:18:11.248218
1	admin	\N	2025-04-06 20:20:53.067592	2025-04-06 20:20:53.067592
3	STYGUS	\N	2025-04-06 22:56:16.168522	2025-04-06 22:56:16.168522
\.


--
-- TOC entry 5056 (class 0 OID 41059)
-- Dependencies: 234
-- Data for Name: test_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_answers (id, attempt_id, question_id, selected_answer_id, is_correct) FROM stdin;
\.


--
-- TOC entry 5058 (class 0 OID 41067)
-- Dependencies: 236
-- Data for Name: test_attempts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_attempts (id, user_id, test_id, score, total_questions, passed, created_at) FROM stdin;
\.


--
-- TOC entry 5060 (class 0 OID 41078)
-- Dependencies: 238
-- Data for Name: tests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tests (id, course_id, author_id, title, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 5062 (class 0 OID 41087)
-- Dependencies: 240
-- Data for Name: user_chapter; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_chapter (id, user_id, chapter_id, is_completed, last_viewed) FROM stdin;
\.


--
-- TOC entry 5064 (class 0 OID 41096)
-- Dependencies: 242
-- Data for Name: user_courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_courses (id, user_id, course_id, progress, status, created_at) FROM stdin;
\.


--
-- TOC entry 5066 (class 0 OID 41106)
-- Dependencies: 244
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, email, password, created_at, updated_at, role_id, is_verified, verification_token_id) FROM stdin;
6	test	test	test@testowy.pl	$2b$10$iY5PO4x5z/cWBKOSbB49UOq8nh8UA0B2ulQoNlriXrrMMsXIi7zOi	2025-04-06 20:18:40.52964	2025-04-06 20:18:40.52964	1	t	\N
7	Jakub	Tokarczyk	jtokarczyk@interia.pl	$2b$10$9x9VaIpIZizZrqKBZA12Tuz0BHhBgPB0eQoAkwAEHhSumetvDV0EK	2025-04-06 22:56:58.584323	2025-04-06 22:56:58.584323	3	t	\N
8	marcin	Dudek	marcin@dudek.pl	$2b$10$vXWGw.z402mHqMUeW5v7uOrYM/g.O2CFIBu9hL23.HhCuputRBSxW	2025-04-08 10:25:48.746355	2025-04-08 10:25:48.746355	2	t	\N
9	kuba	nowaczkiewicz	knowak@interia.pl	$2b$10$LRJXsUL5Fs85HN36eXZgAOoUuGC/0726xmW9DAs27Onv3WI1j37GS	2025-04-08 13:40:27.125034	2025-04-08 13:40:27.125034	2	t	\N
\.


--
-- TOC entry 5068 (class 0 OID 41119)
-- Dependencies: 246
-- Data for Name: verification_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_tokens (id, user_id, verification_token, created_at, expires_at) FROM stdin;
\.


--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 218
-- Name: answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.answers_id_seq', 1, false);


--
-- TOC entry 5097 (class 0 OID 0)
-- Dependencies: 220
-- Name: certificates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificates_id_seq', 1, false);


--
-- TOC entry 5098 (class 0 OID 0)
-- Dependencies: 249
-- Name: chapter_block_attributes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_block_attributes_id_seq', 1523, true);


--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 247
-- Name: chapter_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapter_blocks_id_seq', 1297, true);


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 222
-- Name: chapters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chapters_id_seq', 31, true);


--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 224
-- Name: courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.courses_id_seq', 4, true);


--
-- TOC entry 5102 (class 0 OID 0)
-- Dependencies: 226
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permissions_id_seq', 1, false);


--
-- TOC entry 5103 (class 0 OID 0)
-- Dependencies: 228
-- Name: questions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.questions_id_seq', 1, false);


--
-- TOC entry 5104 (class 0 OID 0)
-- Dependencies: 231
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 1, false);


--
-- TOC entry 5105 (class 0 OID 0)
-- Dependencies: 233
-- Name: test_answers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_answers_id_seq', 1, false);


--
-- TOC entry 5106 (class 0 OID 0)
-- Dependencies: 235
-- Name: test_attempts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_attempts_id_seq', 1, false);


--
-- TOC entry 5107 (class 0 OID 0)
-- Dependencies: 237
-- Name: tests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tests_id_seq', 1, false);


--
-- TOC entry 5108 (class 0 OID 0)
-- Dependencies: 239
-- Name: user_chapter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_chapter_id_seq', 1, false);


--
-- TOC entry 5109 (class 0 OID 0)
-- Dependencies: 241
-- Name: user_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_courses_id_seq', 1, false);


--
-- TOC entry 5110 (class 0 OID 0)
-- Dependencies: 243
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 10, true);


--
-- TOC entry 5111 (class 0 OID 0)
-- Dependencies: 245
-- Name: verification_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_tokens_id_seq', 5, true);


--
-- TOC entry 4831 (class 2606 OID 40970)
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4833 (class 2606 OID 40985)
-- Name: answers answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (id);


--
-- TOC entry 4836 (class 2606 OID 40996)
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);


--
-- TOC entry 4869 (class 2606 OID 41266)
-- Name: chapter_block_attributes chapter_block_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_pkey PRIMARY KEY (id);


--
-- TOC entry 4867 (class 2606 OID 41252)
-- Name: chapter_blocks chapter_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_pkey PRIMARY KEY (id);


--
-- TOC entry 4838 (class 2606 OID 41007)
-- Name: chapters chapters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_pkey PRIMARY KEY (id);


--
-- TOC entry 4840 (class 2606 OID 41019)
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- TOC entry 4842 (class 2606 OID 41030)
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4844 (class 2606 OID 41039)
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- TOC entry 4846 (class 2606 OID 41046)
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- TOC entry 4848 (class 2606 OID 41057)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 4850 (class 2606 OID 41065)
-- Name: test_answers test_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_answers
    ADD CONSTRAINT test_answers_pkey PRIMARY KEY (id);


--
-- TOC entry 4852 (class 2606 OID 41076)
-- Name: test_attempts test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 4854 (class 2606 OID 41085)
-- Name: tests tests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_pkey PRIMARY KEY (id);


--
-- TOC entry 4856 (class 2606 OID 41094)
-- Name: user_chapter user_chapter_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_pkey PRIMARY KEY (id);


--
-- TOC entry 4859 (class 2606 OID 41104)
-- Name: user_courses user_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_pkey PRIMARY KEY (id);


--
-- TOC entry 4863 (class 2606 OID 41117)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4865 (class 2606 OID 41125)
-- Name: verification_tokens verificationtokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_pkey PRIMARY KEY (id);


--
-- TOC entry 4834 (class 1259 OID 41126)
-- Name: certificates_certificate_code_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX certificates_certificate_code_key ON public.certificates USING btree (certificate_code);


--
-- TOC entry 4857 (class 1259 OID 41127)
-- Name: user_chapter_user_id_chapter_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_chapter_user_id_chapter_id_key ON public.user_chapter USING btree (user_id, chapter_id);


--
-- TOC entry 4860 (class 1259 OID 41128)
-- Name: user_courses_user_id_course_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_courses_user_id_course_id_key ON public.user_courses USING btree (user_id, course_id);


--
-- TOC entry 4861 (class 1259 OID 41129)
-- Name: users_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);


--
-- TOC entry 4870 (class 2606 OID 41130)
-- Name: answers answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers
    ADD CONSTRAINT answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- TOC entry 4871 (class 2606 OID 41135)
-- Name: certificates certificates_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 4872 (class 2606 OID 41140)
-- Name: certificates certificates_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4893 (class 2606 OID 41267)
-- Name: chapter_block_attributes chapter_block_attributes_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_block_attributes
    ADD CONSTRAINT chapter_block_attributes_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.chapter_blocks(id) ON DELETE CASCADE;


--
-- TOC entry 4892 (class 2606 OID 41253)
-- Name: chapter_blocks chapter_blocks_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapter_blocks
    ADD CONSTRAINT chapter_blocks_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 4873 (class 2606 OID 41145)
-- Name: chapters chapters_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chapters
    ADD CONSTRAINT chapters_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 4874 (class 2606 OID 41150)
-- Name: courses courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4889 (class 2606 OID 41225)
-- Name: users fk_role_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_role_id FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE SET NULL;


--
-- TOC entry 4875 (class 2606 OID 41155)
-- Name: questions questions_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 4876 (class 2606 OID 41160)
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- TOC entry 4877 (class 2606 OID 41165)
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- TOC entry 4878 (class 2606 OID 41170)
-- Name: test_answers test_answers_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_answers
    ADD CONSTRAINT test_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.test_attempts(id) ON DELETE CASCADE;


--
-- TOC entry 4879 (class 2606 OID 41175)
-- Name: test_answers test_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_answers
    ADD CONSTRAINT test_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id) ON DELETE CASCADE;


--
-- TOC entry 4880 (class 2606 OID 41180)
-- Name: test_answers test_answers_selected_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_answers
    ADD CONSTRAINT test_answers_selected_answer_id_fkey FOREIGN KEY (selected_answer_id) REFERENCES public.answers(id) ON DELETE CASCADE;


--
-- TOC entry 4881 (class 2606 OID 41185)
-- Name: test_attempts test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE CASCADE;


--
-- TOC entry 4882 (class 2606 OID 41190)
-- Name: test_attempts test_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4883 (class 2606 OID 41195)
-- Name: tests tests_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 4884 (class 2606 OID 41200)
-- Name: tests tests_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tests
    ADD CONSTRAINT tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 4885 (class 2606 OID 41205)
-- Name: user_chapter user_chapter_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapters(id) ON DELETE CASCADE;


--
-- TOC entry 4886 (class 2606 OID 41210)
-- Name: user_chapter user_chapter_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_chapter
    ADD CONSTRAINT user_chapter_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4887 (class 2606 OID 41215)
-- Name: user_courses user_courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- TOC entry 4888 (class 2606 OID 41220)
-- Name: user_courses user_courses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_courses
    ADD CONSTRAINT user_courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4890 (class 2606 OID 41230)
-- Name: users users_id_verificationtoken_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_verificationtoken_fkey FOREIGN KEY (verification_token_id) REFERENCES public.verification_tokens(id);


--
-- TOC entry 4891 (class 2606 OID 41235)
-- Name: verification_tokens verificationtokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verificationtokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2025-04-10 23:44:17

--
-- PostgreSQL database dump complete
--

