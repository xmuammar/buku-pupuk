export const editRecordSql=`WITH candidate AS (
 SELECT id,type,date,name,product,qty,sacks,unit_price,amount,paid,ref,note,receipt_name,receipt_data,sale_kind,member_id FROM records WHERE id<>?
 UNION ALL SELECT ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
)
UPDATE records SET date=?,name=?,product=?,qty=?,sacks=?,unit_price=?,amount=?,paid=?,ref=?,note=?,receipt_name=?,receipt_data=?,sale_kind=?,member_id=?
WHERE id=? AND type=?
 AND date=? AND name=? AND product=? AND qty=? AND sacks=? AND unit_price=? AND amount=? AND paid=? AND ref=? AND note=? AND receipt_name=? AND receipt_data=? AND sale_kind=? AND member_id=?
 AND NOT EXISTS (
   SELECT 1 FROM candidate WHERE type IN ('purchase','sale') GROUP BY product
   HAVING SUM(CASE WHEN type='purchase' THEN qty ELSE -qty END)<-0.00000001
 )
 AND NOT EXISTS (
   SELECT 1 FROM candidate t WHERE t.type IN ('purchase','sale') AND t.amount-t.paid-
   COALESCE((SELECT SUM(p.amount) FROM candidate p WHERE p.ref=t.id AND p.type=CASE WHEN t.type='purchase' THEN 'pay' ELSE 'collect' END),0)<0
 )
 AND NOT EXISTS (
   SELECT 1 FROM candidate p WHERE p.type IN ('pay','collect') AND NOT EXISTS (
     SELECT 1 FROM candidate t WHERE t.id=p.ref AND t.type=CASE WHEN p.type='pay' THEN 'purchase' ELSE 'sale' END
   )
 )`;
