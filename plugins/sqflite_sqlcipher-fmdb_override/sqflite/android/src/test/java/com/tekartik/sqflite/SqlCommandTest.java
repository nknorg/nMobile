package com.tekartik.sqflite;

import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;

/**
 * Constants between dart & Java world
 */

public class SqlCommandTest {


    @Test
    public void noParam() {
        SqlCommand command = new SqlCommand(null, null);
        assertEquals(command.getSql(), null);
        assertEquals(command.getRawSqlArguments(), new ArrayList<>());
    }

    @Test
    public void sqlArguments() {
        List<Object> arguments = Arrays.asList((Object) 1L, 2, "text",
                1.234f,
                4.5678, // double
                new byte[]{1, 2, 3});
        SqlCommand command = new SqlCommand(null, arguments);
        /*
        assertEquals(Arrays.asList(1L, 2, "text",
                1.234f,
                4.5678, // double
                new byte[] {1,2, 3}), command.getRawSqlArguments());
                */
        assertArrayEquals(new Object[]{1L, 2, "text",
                1.234f,
                4.5678, // double
                new byte[]{1, 2, 3}}, command.getSqlArguments());
        assertArrayEquals(new String[]{"1", "2", "text",
                "1.234",
                "4.5678", // double
                "[1, 2, 3]"}, command.getQuerySqlArguments());

    }

    @Test
    public void equals() {
        SqlCommand command1 = new SqlCommand(null, null);
        SqlCommand command2 = new SqlCommand(null, new ArrayList<Object>());
        assertEquals(command1, command2);
        command1 = new SqlCommand("", null);
        assertNotEquals(command1, command2);
        assertNotEquals(command2, command1);
        command1 = new SqlCommand(null, Arrays.asList((Object) "test"));
        assertNotEquals(command1, command2);
        assertNotEquals(command2, command1);
        command2 = new SqlCommand(null, Arrays.asList((Object) "test"));
        assertEquals(command1, command2);
        command1 = new SqlCommand(null, Arrays.asList((Object) "test_"));
        assertNotEquals(command1, command2);
        assertNotEquals(command2, command1);
        command1 = new SqlCommand(null, Arrays.asList((Object) new byte[]{1, 2, 3}));
        command2 = new SqlCommand(null, Arrays.asList((Object) new byte[]{1, 2, 3}));
        assertEquals(command1, command2);
        command1 = new SqlCommand(null, Arrays.asList((Object) new byte[]{1, 2}));
        assertNotEquals(command1, command2);
        assertNotEquals(command2, command1);
    }

    @Test
    public void sanitizeQuery() {
        SqlCommand command = new SqlCommand("?", Arrays.asList((Object) 1));
        assertEquals(new SqlCommand("1", null), command.sanitizeForQuery());
        command = new SqlCommand("?", Arrays.asList((Object) 1, 2));
        assertEquals(command, command.sanitizeForQuery());
        command = new SqlCommand("?", null);
        assertEquals(command, command.sanitizeForQuery());
        command = new SqlCommand(null, null);
        assertEquals(command, command.sanitizeForQuery());
        command = new SqlCommand("?,?,?,?,?,?", Arrays.asList((Object) 1L, 2, "text",
                1.234f,
                4.5678, // double
                new byte[]{1, 2, 3}));
        assertEquals(new SqlCommand("1,2,?,?,?,?", Arrays.asList((Object) "text",
                1.234f,
                4.5678, // double
                new byte[]{1, 2, 3})), command.sanitizeForQuery());

    }

    @Test
    public void indexedParam() {
        SqlCommand command = new SqlCommand("?1", Arrays.asList((Object) 1));
        assertEquals(new SqlCommand("?1", Arrays.asList((Object) 1)), command.sanitizeForQuery());
    }
}
