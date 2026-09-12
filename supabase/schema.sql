-- ====================================================================
-- FreshRoute Agro-Intelligence Platform - Supabase PostgreSQL Schema
-- Complete Relational Migration for Harvest Batches, Buyers, Logistics & Orders
-- ====================================================================

-- 0. Ensure UUID generation extension is active
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ====================================================================
-- 1. PROFILES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('farmer', 'buyer')),
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    language TEXT DEFAULT 'en' CHECK (language IN ('en', 'hi', 'kn', 'mr')),
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);

-- ====================================================================
-- 2. FARMERS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.farmers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    farm_name TEXT NOT NULL,
    location TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_farmers_profile ON public.farmers(profile_id);
CREATE INDEX IF NOT EXISTS idx_farmers_location ON public.farmers(location);

-- ====================================================================
-- 3. BUYERS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.buyers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    business_type TEXT NOT NULL CHECK (business_type IN (
        'Retail Chain',
        'Food Processor',
        'Mandir/Catering Wholesale',
        'Quick-Commerce Dark Store',
        'Export House',
        'Supermarket',
        'Restaurant / Hotel',
        'Wholesale Trader'
    )),
    location TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_buyers_profile ON public.buyers(profile_id);
CREATE INDEX IF NOT EXISTS idx_buyers_type ON public.buyers(business_type);

-- ====================================================================
-- 4. PRODUCE BATCHES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.produce_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_id UUID NOT NULL REFERENCES public.farmers(id) ON DELETE CASCADE,
    crop TEXT NOT NULL,
    variety TEXT,
    quantity_kg NUMERIC(10,2) NOT NULL CHECK (quantity_kg > 0),
    harvest_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    quality_score NUMERIC(5,2) CHECK (quality_score >= 0 AND quality_score <= 100),
    quality_grade TEXT CHECK (quality_grade IN ('A', 'B', 'C', 'D', 'Grade A', 'Grade B', 'Grade C', 'Grade D')),
    freshness NUMERIC(5,2) CHECK (freshness >= 0 AND freshness <= 100),
    spoilage_risk NUMERIC(5,2) CHECK (spoilage_risk >= 0 AND spoilage_risk <= 100),
    estimated_shelf_life NUMERIC(10,2), -- Remaining shelf life in hours
    quality_confidence NUMERIC(5,2) CHECK (quality_confidence >= 0 AND quality_confidence <= 100),
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'sold', 'in_transit', 'spoiled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_batches_farmer ON public.produce_batches(farmer_id);
CREATE INDEX IF NOT EXISTS idx_batches_crop ON public.produce_batches(crop);
CREATE INDEX IF NOT EXISTS idx_batches_status ON public.produce_batches(status);
CREATE INDEX IF NOT EXISTS idx_batches_created ON public.produce_batches(created_at DESC);

-- ====================================================================
-- 5. MARKET PRICES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.market_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    crop TEXT NOT NULL,
    market_name TEXT NOT NULL,
    location TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    min_price NUMERIC(10,2) NOT NULL CHECK (min_price >= 0),
    modal_price NUMERIC(10,2) NOT NULL CHECK (modal_price >= 0),
    max_price NUMERIC(10,2) NOT NULL CHECK (max_price >= min_price),
    price_date DATE NOT NULL DEFAULT CURRENT_DATE,
    source TEXT NOT NULL DEFAULT 'APMC / Mandi',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_market_prices_crop_date ON public.market_prices(crop, price_date DESC);
CREATE INDEX IF NOT EXISTS idx_market_prices_market ON public.market_prices(market_name);

-- ====================================================================
-- 6. BUYER DEMAND
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.buyer_demand (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES public.buyers(id) ON DELETE CASCADE,
    crop TEXT NOT NULL,
    quantity_required_kg NUMERIC(10,2) NOT NULL CHECK (quantity_required_kg > 0),
    offered_price NUMERIC(10,2) NOT NULL CHECK (offered_price > 0),
    required_by TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'matched', 'fulfilled', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_buyer_demand_crop ON public.buyer_demand(crop);
CREATE INDEX IF NOT EXISTS idx_buyer_demand_buyer ON public.buyer_demand(buyer_id);
CREATE INDEX IF NOT EXISTS idx_buyer_demand_status ON public.buyer_demand(status);

-- ====================================================================
-- 7. TRANSPORT OPTIONS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.transport_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_type TEXT NOT NULL,
    capacity_kg NUMERIC(10,2) NOT NULL CHECK (capacity_kg > 0),
    cost_per_km NUMERIC(10,2) NOT NULL CHECK (cost_per_km >= 0),
    availability BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transport_availability ON public.transport_options(availability);

-- ====================================================================
-- 8. RECOMMENDATIONS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produce_batch_id UUID NOT NULL REFERENCES public.produce_batches(id) ON DELETE CASCADE,
    recommended_action TEXT NOT NULL,
    recommended_buyer_id UUID REFERENCES public.buyers(id) ON DELETE SET NULL,
    recommended_market TEXT,
    estimated_revenue NUMERIC(12,2),
    transport_cost NUMERIC(10,2),
    estimated_spoilage_loss NUMERIC(10,2),
    expected_recoverable_value NUMERIC(12,2),
    confidence NUMERIC(5,2) CHECK (confidence >= 0 AND confidence <= 100),
    explanation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recommendations_batch ON public.recommendations(produce_batch_id);

-- ====================================================================
-- 9. ORDERS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES public.buyers(id) ON DELETE RESTRICT,
    farmer_id UUID NOT NULL REFERENCES public.farmers(id) ON DELETE RESTRICT,
    produce_batch_id UUID NOT NULL REFERENCES public.produce_batches(id) ON DELETE RESTRICT,
    quantity_kg NUMERIC(10,2) NOT NULL CHECK (quantity_kg > 0),
    agreed_price NUMERIC(10,2) NOT NULL CHECK (agreed_price > 0),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',
        'confirmed',
        'in_transit',
        'delivered',
        'completed',
        'cancelled'
    )),
    pickup_location TEXT NOT NULL,
    delivery_location TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_buyer ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_farmer ON public.orders(farmer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_batch ON public.orders(produce_batch_id);

-- ====================================================================
-- 10. WHATSAPP CONVERSATIONS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.whatsapp_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'kn', 'mr')),
    state TEXT NOT NULL DEFAULT 'IDLE',
    context_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_phone ON public.whatsapp_conversations(phone_number);

-- ====================================================================
-- 11. WHATSAPP MESSAGES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.whatsapp_conversations(id) ON DELETE CASCADE,
    direction TEXT NOT NULL CHECK (direction IN ('incoming', 'outgoing')),
    message_type TEXT NOT NULL CHECK (message_type IN ('text', 'image', 'location', 'interactive', 'template', 'voice')),
    message_text TEXT,
    media_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_conv ON public.whatsapp_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_created ON public.whatsapp_messages(created_at);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- 1. Profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_policy" ON public.profiles
    FOR SELECT USING (
        auth.uid() = user_id 
        OR auth.role() IN ('authenticated', 'anon')
    );

CREATE POLICY "profiles_insert_policy" ON public.profiles
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        OR user_id IS NULL
        OR auth.role() IN ('authenticated', 'anon')
    );

CREATE POLICY "profiles_update_policy" ON public.profiles
    FOR UPDATE USING (
        auth.uid() = user_id 
        OR auth.role() IN ('authenticated', 'anon')
    );

-- 2. Farmers RLS
ALTER TABLE public.farmers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "farmers_select_policy" ON public.farmers
    FOR SELECT USING (true);

CREATE POLICY "farmers_modify_policy" ON public.farmers
    FOR ALL USING (
        profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
        OR auth.role() IN ('authenticated', 'anon')
    );

-- 3. Buyers RLS
ALTER TABLE public.buyers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "buyers_select_policy" ON public.buyers
    FOR SELECT USING (true);

CREATE POLICY "buyers_modify_policy" ON public.buyers
    FOR ALL USING (
        profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
        OR auth.role() IN ('authenticated', 'anon')
    );

-- 4. Produce Batches RLS
ALTER TABLE public.produce_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "batches_select_policy" ON public.produce_batches
    FOR SELECT USING (true);

CREATE POLICY "batches_farmer_manage" ON public.produce_batches
    FOR ALL USING (
        farmer_id IN (
            SELECT f.id FROM public.farmers f
            JOIN public.profiles p ON f.profile_id = p.id
            WHERE p.user_id = auth.uid()
        )
        OR auth.role() IN ('authenticated', 'anon')
    );

-- 5. Market Prices RLS (Public read, authenticated insert)
ALTER TABLE public.market_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "market_prices_select_policy" ON public.market_prices
    FOR SELECT USING (true);

CREATE POLICY "market_prices_write_policy" ON public.market_prices
    FOR ALL USING (auth.role() IN ('authenticated', 'anon'));

-- 6. Buyer Demand RLS
ALTER TABLE public.buyer_demand ENABLE ROW LEVEL SECURITY;

CREATE POLICY "buyer_demand_select_policy" ON public.buyer_demand
    FOR SELECT USING (true);

CREATE POLICY "buyer_demand_manage_policy" ON public.buyer_demand
    FOR ALL USING (
        buyer_id IN (
            SELECT b.id FROM public.buyers b
            JOIN public.profiles p ON b.profile_id = p.id
            WHERE p.user_id = auth.uid()
        )
        OR auth.role() IN ('authenticated', 'anon')
    );

-- 7. Transport Options RLS
ALTER TABLE public.transport_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transport_select_policy" ON public.transport_options
    FOR SELECT USING (true);

CREATE POLICY "transport_write_policy" ON public.transport_options
    FOR ALL USING (auth.role() IN ('authenticated', 'anon'));

-- 8. Recommendations RLS
ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recommendations_select_policy" ON public.recommendations
    FOR SELECT USING (true);

CREATE POLICY "recommendations_write_policy" ON public.recommendations
    FOR ALL USING (auth.role() IN ('authenticated', 'anon'));

-- 9. Orders RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "orders_select_policy" ON public.orders
    FOR SELECT USING (
        buyer_id IN (
            SELECT b.id FROM public.buyers b
            JOIN public.profiles p ON b.profile_id = p.id
            WHERE p.user_id = auth.uid()
        )
        OR farmer_id IN (
            SELECT f.id FROM public.farmers f
            JOIN public.profiles p ON f.profile_id = p.id
            WHERE p.user_id = auth.uid()
        )
        OR auth.role() IN ('authenticated', 'anon')
    );

CREATE POLICY "orders_insert_policy" ON public.orders
    FOR INSERT WITH CHECK (auth.role() IN ('authenticated', 'anon'));

CREATE POLICY "orders_update_policy" ON public.orders
    FOR UPDATE USING (auth.role() IN ('authenticated', 'anon'));

-- 10. WhatsApp Conversations RLS
ALTER TABLE public.whatsapp_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "whatsapp_conv_policy" ON public.whatsapp_conversations
    FOR ALL USING (auth.role() IN ('authenticated', 'anon'));

-- 11. WhatsApp Messages RLS
ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "whatsapp_msg_policy" ON public.whatsapp_messages
    FOR ALL USING (auth.role() IN ('authenticated', 'anon'));

-- ====================================================================
-- INITIAL SEED DATA (FreshRoute Demo Baseline)
-- ====================================================================

-- Seed Profiles
INSERT INTO public.profiles (id, role, full_name, phone, email, language, location)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'farmer', 'Ramesh Patil', '+91 98220 12345', 'ramesh.patil@kisanmail.in', 'kn', 'Niphad, Nashik, Maharashtra'),
    ('22222222-2222-2222-2222-222222222222', 'buyer', 'Anil Sharma', '+91 98110 33411', 'anil.sharma@freshmart.co.in', 'en', 'Bhandup Central DC, Mumbai')
ON CONFLICT (id) DO NOTHING;

-- Seed Farmers
INSERT INTO public.farmers (id, profile_id, farm_name, location, latitude, longitude)
VALUES 
    ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Patil Organic Agri Farms', 'Niphad, Nashik, Maharashtra', 20.0789, 74.1089)
ON CONFLICT (id) DO NOTHING;

-- Seed Buyers
INSERT INTO public.buyers (id, profile_id, business_name, business_type, location, latitude, longitude)
VALUES 
    ('44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'FreshMart Quick Commerce', 'Quick-Commerce Dark Store', 'Bhandup Central DC, Mumbai', 19.1465, 72.9345)
ON CONFLICT (id) DO NOTHING;

-- Seed Produce Batches
INSERT INTO public.produce_batches (
    id, farmer_id, crop, variety, quantity_kg, harvest_time, 
    quality_score, quality_grade, freshness, spoilage_risk, 
    estimated_shelf_life, quality_confidence, image_url, status
)
VALUES 
    (
        '55555555-5555-5555-5555-555555555551',
        '33333333-3333-3333-3333-333333333333',
        'Tomatoes',
        'Abhinav Hybrid (Table Grade)',
        850.00,
        now() - INTERVAL '4 hours',
        82.00,
        'Grade A',
        88.00,
        18.00,
        32.00,
        94.50,
        'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80',
        'available'
    ),
    (
        '55555555-5555-5555-5555-555555555552',
        '33333333-3333-3333-3333-333333333333',
        'Onions',
        'Nashik Red Garwa',
        1400.00,
        now() - INTERVAL '1 day',
        78.50,
        'Grade B',
        82.00,
        22.00,
        120.00,
        91.00,
        'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=800&q=80',
        'available'
    ),
    (
        '55555555-5555-5555-5555-555555555553',
        '33333333-3333-3333-3333-333333333333',
        'Grapes',
        'Thompson Seedless',
        650.00,
        now() - INTERVAL '6 hours',
        86.00,
        'Grade A',
        90.00,
        14.00,
        48.00,
        96.00,
        'https://images.unsplash.com/photo-1537640538966-79f369143f8f?auto=format&fit=crop&w=800&q=80',
        'available'
    )
ON CONFLICT (id) DO NOTHING;

-- Seed Market Prices (APMC benchmarks)
INSERT INTO public.market_prices (crop, market_name, location, latitude, longitude, min_price, modal_price, max_price, price_date, source)
VALUES 
    ('Tomatoes', 'Pimpalgaon Baswant APMC', 'Nashik, Maharashtra', 20.1700, 73.9800, 14.00, 22.00, 26.50, CURRENT_DATE, 'Agmarknet APMC'),
    ('Tomatoes', 'Vashi APMC Wholesale', 'Navi Mumbai, Maharashtra', 19.0760, 72.9980, 18.00, 26.50, 31.00, CURRENT_DATE, 'Agmarknet APMC'),
    ('Onions', 'Lasalgaon APMC', 'Nashik, Maharashtra', 20.1472, 74.2267, 12.50, 18.20, 23.00, CURRENT_DATE, 'Agmarknet APMC'),
    ('Potatoes', 'Pune Gultekdi APMC', 'Pune, Maharashtra', 18.4900, 73.8600, 15.00, 20.00, 24.50, CURRENT_DATE, 'Agmarknet APMC'),
    ('Grapes', 'Dindori APMC', 'Nashik, Maharashtra', 20.2000, 73.8300, 45.00, 62.00, 78.00, CURRENT_DATE, 'Agmarknet APMC')
ON CONFLICT DO NOTHING;

-- Seed Transport Options
INSERT INTO public.transport_options (vehicle_type, capacity_kg, cost_per_km, availability)
VALUES 
    ('Tata Ace Mini-Pickup (Cushioned Bed)', 750.00, 14.00, true),
    ('Mahindra Bolero Maxi Truck', 1500.00, 18.50, true),
    ('Eicher 14ft Active Reefer (12°C-15°C Chilled)', 3500.00, 28.00, true),
    ('Ashok Leyland 19ft Ventilated Canopy', 6000.00, 36.00, true)
ON CONFLICT DO NOTHING;

-- Seed Buyer Demand
INSERT INTO public.buyer_demand (id, buyer_id, crop, quantity_required_kg, offered_price, required_by, status)
VALUES 
    (
        '66666666-6666-6666-6666-666666666661',
        '44444444-4444-4444-4444-444444444444',
        'Tomatoes',
        1000.00,
        34.00,
        now() + INTERVAL '24 hours',
        'open'
    ),
    (
        '66666666-6666-6666-6666-666666666662',
        '44444444-4444-4444-4444-444444444444',
        'Grapes',
        500.00,
        75.00,
        now() + INTERVAL '48 hours',
        'open'
    )
ON CONFLICT (id) DO NOTHING;

-- Seed Recommendations
INSERT INTO public.recommendations (
    produce_batch_id, recommended_action, recommended_buyer_id, 
    recommended_market, estimated_revenue, transport_cost, 
    estimated_spoilage_loss, expected_recoverable_value, confidence, explanation
)
VALUES (
    '55555555-5555-5555-5555-555555555551',
    'SELL_IMMEDIATE_DIRECT',
    '44444444-4444-4444-4444-444444444444',
    'FreshMart Mumbai DC',
    28900.00,
    1190.00,
    420.00,
    27290.00,
    94.00,
    'Selling table tomatoes immediately to FreshMart bypasses 6.5% APMC mandi cut and nets +₹11,400 more than distress mandi dumping.'
)
ON CONFLICT DO NOTHING;

-- Seed Initial Order
INSERT INTO public.orders (
    id, buyer_id, farmer_id, produce_batch_id, 
    quantity_kg, agreed_price, total_amount, status, 
    pickup_location, delivery_location
)
VALUES (
    '77777777-7777-7777-7777-777777777777',
    '44444444-4444-4444-4444-444444444444',
    '33333333-3333-3333-3333-333333333333',
    '55555555-5555-5555-5555-555555555551',
    800.00,
    21.50,
    17200.00,
    'in_transit',
    'Niphad Farm Gate, Nashik',
    'FreshMart Central DC, Mumbai'
)
ON CONFLICT (id) DO NOTHING;
