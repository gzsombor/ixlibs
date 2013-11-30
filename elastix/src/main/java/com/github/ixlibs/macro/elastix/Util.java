package com.github.ixlibs.macro.elastix;

import java.util.Date;

public class Util {

    private Util() {
    }

    public static Long toLong(Object obj) {
        if (obj instanceof Long) {
            return (Long) obj;
        } else if (obj instanceof Number) {
            return ((Number) obj).longValue();
        }
        if (obj != null) {
            throw new RuntimeException("Unable to convert to Long:" + obj + " " + obj.getClass().getName());
        }
        return null;
    }

    public static Integer toInteger(Object obj) {
        if (obj instanceof Integer) {
            return (Integer) obj;
        } else if (obj instanceof Number) {
            return ((Number) obj).intValue();
        }
        if (obj != null) {
            throw new RuntimeException("Unable to convert to Integer:" + obj + " " + obj.getClass().getName());
        }
        return null;
    }

    public static long tolong(Object obj) {
        if (obj instanceof Number) {
            return ((Number) obj).longValue();
        }
        if (obj != null) {
            throw new RuntimeException("Unable to convert to long:" + obj + " " + obj.getClass().getName());
        }
        return 0;
    }

    public static int toint(Object obj) {
        if (obj instanceof Number) {
            return ((Number) obj).intValue();
        }
        if (obj != null) {
            throw new RuntimeException("Unable to convert to int:" + obj + " " + obj.getClass().getName());
        }
        return 0;
    }

    public static String toString(Object obj) {
        if (obj != null) {
            return obj.toString();
        }
        return null;
    }

    public static Date toDate(Object obj) {
        if (obj instanceof Date) {
            return (Date) obj;
        }
        if (obj instanceof Number) {
            return new Date(((Number) obj).longValue());
        }
        if (obj != null) {
            throw new RuntimeException("Unable to convert to Date:" + obj + " " + obj.getClass().getName());
        }
        return null;
    }
}
