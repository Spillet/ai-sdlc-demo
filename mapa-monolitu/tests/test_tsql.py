"""Testy parseru na pastech, které naivní regex chytá špatně.  python3 -m unittest discover tests"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapa import tsql  # noqa: E402


def refs(sql, op=None):
    o = tsql.parse_object(sql)
    return sorted({(r["name"], r["op"]) for r in o["refs"] if op is None or r["op"] == op})


class ParserTest(unittest.TestCase):
    def test_comment_is_not_dependency(self):
        sql = "CREATE PROCEDURE dbo.p AS\n-- puvodne FROM dbo.OldOrders\n/* UPDATE dbo.X */ SELECT 1 FROM dbo.Orders"
        self.assertEqual(refs(sql), [("Orders", "read")])

    def test_string_literal_is_not_dependency(self):
        sql = "CREATE PROCEDURE dbo.p AS EXEC dbo.usp_Audit_Write @Msg = N'Update dbo.Invoice failed'"
        self.assertEqual(refs(sql), [("usp_Audit_Write", "exec")])

    def test_update_through_alias(self):
        sql = "CREATE PROCEDURE dbo.p AS UPDATE sl SET sl.Qty = 0 FROM dbo.StockLevel AS sl JOIN dbo.OrderItem oi ON 1=1"
        self.assertIn(("StockLevel", "write"), refs(sql))
        self.assertIn(("OrderItem", "read"), refs(sql))

    def test_exec_without_schema_and_return_value(self):
        sql = "CREATE PROC dbo.p AS BEGIN EXEC @rc = dbo.a; EXEC b @x = 1; END"
        o = tsql.parse_object(sql)
        got = {(r["name"], r["schema"]) for r in o["refs"] if r["op"] == "exec"}
        self.assertEqual(got, {("a", "dbo"), ("b", "")})

    def test_temp_tables_ignored(self):
        sql = "CREATE PROCEDURE dbo.p AS INSERT INTO #work SELECT * FROM dbo.Orders; DROP TABLE #work"
        self.assertEqual(refs(sql), [("Orders", "read")])

    def test_cross_db(self):
        o = tsql.parse_object("CREATE PROCEDURE dbo.p AS INSERT INTO Archive.dbo.T SELECT * FROM dbo.T")
        self.assertTrue(any(r["db"] == "Archive" for r in o["refs"]))

    def test_dynamic_literal_resolvable(self):
        sql = ("CREATE PROCEDURE dbo.p @s INT AS DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM dbo.Claim WHERE 1=1';\n"
               "SET @sql += N' AND Status = @s'; EXEC sp_executesql @sql, N'@s INT', @s = @s;")
        d = tsql.parse_object(sql)["dynamic"]
        self.assertEqual(d["tables"], [("Claim", "read")])
        self.assertFalse(d["blind"])

    def test_dynamic_concatenated_name_is_blind(self):
        sql = ("CREATE PROCEDURE dbo.p @y INT AS DECLARE @sql NVARCHAR(MAX);\n"
               "SET @sql = N'INSERT INTO dbo.Sales_' + CAST(@y AS NVARCHAR(4)) + N' SELECT * FROM dbo.Orders';\nEXEC (@sql);")
        d = tsql.parse_object(sql)["dynamic"]
        self.assertTrue(d["blind"])
        self.assertIn(("Orders", "read"), d["tables"])

    def test_dispatch_by_proc_name_is_blind(self):
        sql = ("CREATE PROCEDURE dbo.p AS DECLARE @h SYSNAME, @sql NVARCHAR(MAX);\n"
               "SET @sql = N'EXEC dbo.' + QUOTENAME(@h); EXEC (@sql);")
        self.assertTrue(tsql.parse_object(sql)["dynamic"]["blind"])


if __name__ == "__main__":
    unittest.main()
