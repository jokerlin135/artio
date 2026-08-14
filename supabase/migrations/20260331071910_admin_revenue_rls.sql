-- Admin read policy for credit_transactions
-- Allows admins to read all transactions for Revenue page
CREATE POLICY "Admins can read all transactions"
ON credit_transactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = (select auth.uid())
    AND profiles.role = 'admin'
  )
);

-- Partial index for revenue queries (type filter + date range)
-- ASC direction: B-tree range scan friendly with gte() filters
-- Partial: only indexes rows needed for revenue queries
CREATE INDEX IF NOT EXISTS idx_credit_transactions_type_created
ON credit_transactions(type, created_at)
WHERE type IN ('subscription', 'purchase');
