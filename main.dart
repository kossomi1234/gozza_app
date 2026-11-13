import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Keys come from --dart-define. NEVER put the service_role key in this app.
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
SupabaseClient get db => Supabase.instance.client;

// ---------- languages: 0 English, 1 Français, 2 العربية ----------
final lang = ValueNotifier<int>(0);
String t(String k) => _s[k]![lang.value];
const _s = <String, List<String>>{
  'welcome': ['Welcome to Gozza', 'Bienvenue sur Gozza', 'مرحبًا بك في Gozza'],
  'phone': ['Phone number', 'Numéro de téléphone', 'رقم الهاتف'],
  'sendCode': ['Send code', 'Envoyer le code', 'أرسل الرمز'],
  'code': ['Code', 'Code', 'الرمز'],
  'verify': ['Verify', 'Vérifier', 'تحقق'],
  'hood': ['Neighborhood', 'Quartier', 'الحي'],
  'create': ['Create account', 'Créer un compte', 'إنشاء حساب'],
  'client': ['Client', 'Client', 'عميل'],
  'driver': ['Driver', 'Chauffeur', 'سائق'],
  'useDash': ['Please use the owner dashboard.', 'Veuillez utiliser le tableau de bord du propriétaire.', 'يرجى استخدام لوحة تحكم المالك.'],
  'pending': ['Your driver account is waiting for owner approval.', 'Votre compte chauffeur attend l’approbation du propriétaire.', 'حساب السائق بانتظار موافقة المالك.'],
  'online': ['Online', 'En ligne', 'متصل'],
  'none': ['No requests yet', 'Aucune demande pour le moment', 'لا توجد طلبات بعد'],
  'pickup': ['Pickup', 'Départ', 'نقطة الانطلاق'],
  'dropoff': ['Drop-off', 'Destination', 'الوجهة'],
  'request': ['Request', 'Demander', 'اطلب'],
  'accept': ['Accept', 'Accepter', 'قبول'],
  'sent': ['Request sent', 'Demande envoyée', 'تم إرسال الطلب'],
  's_moto': ['Motorcycle ride', 'Course en moto', 'رحلة بدراجة نارية'],
  's_rickshaw': ['Auto-rickshaw', 'Auto-rickshaw', 'توك توك'],
  's_car': ['Private car', 'Voiture privée', 'سيارة خاصة'],
  's_taxi': ['Taxi', 'Taxi', 'تاكسي'],
  's_package': ['Package delivery', 'Livraison de colis', 'توصيل الطرود'],
  's_food': ['Food delivery', 'Livraison de repas', 'توصيل الطعام'],
  's_goods': ['Goods transport', 'Transport de marchandises', 'نقل البضائع'],
};
const _svc = [['moto', '🏍️'], ['rickshaw', '🛺'], ['car', '🚗'], ['taxi', '🚕'], ['package', '📦'], ['food', '🍔'], ['goods', '🚚']];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _url, anonKey: _key);
  runApp(const GozzaApp());
}

class GozzaApp extends StatelessWidget {
  const GozzaApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: lang,
        builder: (_, l, __) => MaterialApp(
          title: 'Gozza',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D28D9)), useMaterial3: true),
          builder: (ctx, child) => Directionality(textDirection: l == 2 ? TextDirection.rtl : TextDirection.ltr, child: child!),
          home: Gate(),
        ),
      );
}

class LangMenu extends StatelessWidget {
  const LangMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        icon: const Icon(Icons.language),
        onSelected: (v) => lang.value = v,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 0, child: Text('English')),
          PopupMenuItem(value: 1, child: Text('Français')),
          PopupMenuItem(value: 2, child: Text('العربية')),
        ],
      );
}

class SignOut extends StatelessWidget {
  const SignOut({super.key});
  @override
  Widget build(BuildContext context) => IconButton(icon: const Icon(Icons.logout), onPressed: () => db.auth.signOut());
}

// ---------- signed in or not ----------
class Gate extends StatelessWidget {
  Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (_, __) => db.auth.currentSession == null ? PhoneLogin() : Home(),
      );
}

// ---------- phone + code login ----------
class PhoneLogin extends StatefulWidget {
  PhoneLogin({super.key});
  @override
  State<PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<PhoneLogin> {
  final _p = TextEditingController(), _c = TextEditingController();
  bool _sent = false, _busy = false;
  String get _phone => '+235${_p.text.replaceAll(RegExp(r'\D'), '')}';

  void _msg(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      if (!_sent) {
        await db.auth.signInWithOtp(phone: _phone);
        _sent = true;
      } else {
        await db.auth.verifyOTP(phone: _phone, token: _c.text.trim(), type: OtpType.sms);
      }
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gozza'), actions: const [LangMenu()]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(t('welcome'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(controller: _p, enabled: !_sent, keyboardType: TextInputType.phone, decoration: InputDecoration(prefixText: '+235 ', labelText: t('phone'), border: const OutlineInputBorder())),
          if (_sent) ...[
            const SizedBox(height: 12),
            TextField(controller: _c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('code'), border: const OutlineInputBorder())),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _go, child: Text(_sent ? t('verify') : t('sendCode'))),
        ]),
      );
}

// ---------- load profile, then show the right screen ----------
class Home extends StatefulWidget {
  Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late Future<Map<String, dynamic>?> _f = _load();
  Future<Map<String, dynamic>?> _load() => db.from('profiles').select().eq('id', db.auth.currentUser!.id).maybeSingle();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Scaffold(appBar: AppBar(actions: const [SignOut()]), body: Center(child: Text('${s.error}')));
          if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final p = s.data;
          if (p == null) return CreateAccount(onDone: () => setState(() => _f = _load()));
          switch (p['role']) {
            case 'driver':
              return DriverHome(profile: p);
            case 'client':
              return ClientHome();
            default:
              return Scaffold(appBar: AppBar(actions: const [SignOut()]), body: Center(child: Text(t('useDash'))));
          }
        },
      );
}

class CreateAccount extends StatefulWidget {
  final VoidCallback onDone;
  CreateAccount({super.key, required this.onDone});
  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final _n = TextEditingController();
  String _role = 'client';

  Future<void> _save() async {
    final u = db.auth.currentUser!;
    try {
      await db.from('profiles').insert({'id': u.id, 'role': _role, 'phone': u.phone, 'neighborhood': _n.text.trim()});
      widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('create')), actions: const [LangMenu(), SignOut()]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'client', label: Text(t('client'))), ButtonSegment(value: 'driver', label: Text(t('driver')))],
            selected: {_role},
            onSelectionChanged: (v) => setState(() => _role = v.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: _n, decoration: InputDecoration(labelText: t('hood'), border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(t('create'))),
        ]),
      );
}

// ---------- client ----------
class ClientHome extends StatelessWidget {
  ClientHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gozza'), actions: const [LangMenu(), SignOut()]),
        body: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            for (final s in _svc)
              Card(
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Booking(service: s[0]))),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s[1], style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(t('s_${s[0]}'), textAlign: TextAlign.center),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      );
}

class Booking extends StatefulWidget {
  final String service;
  Booking({super.key, required this.service});
  @override
  State<Booking> createState() => _BookingState();
}

class _BookingState extends State<Booking> {
  final _a = TextEditingController(), _b = TextEditingController();
  int? _v;
  late final Future<List<Map<String, dynamic>>> _vs = db.from('vehicles').select().eq('service', widget.service).eq('enabled', true).order('base');

  // Estimate only. The real fare is set by the database from the vehicle prices.
  int _est(Map<String, dynamic> v) => (((v['base'] as int) + (v['per_km'] as int) * 4.2) / 50).round() * 50;

  Future<void> _send() async {
    if (_v == null || _a.text.trim().isEmpty || _b.text.trim().isEmpty) return;
    try {
      await db.from('trips').insert({'client_id': db.auth.currentUser!.id, 'vehicle_id': _v, 'pickup': _a.text.trim(), 'dropoff': _b.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('sent'))));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('s_${widget.service}'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _a, decoration: InputDecoration(labelText: t('pickup'), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _b, decoration: InputDecoration(labelText: t('dropoff'), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _vs,
            builder: (_, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              return Column(children: [
                for (final v in s.data!)
                  RadioListTile<int>(
                    value: v['id'] as int,
                    groupValue: _v,
                    onChanged: (x) => setState(() => _v = x),
                    title: Text('${v['name']}'),
                    subtitle: Text('${_est(v)} FCFA'),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _send, child: Text(t('request'))),
        ]),
      );
}

// ---------- driver ----------
class DriverHome extends StatefulWidget {
  final Map<String, dynamic> profile;
  DriverHome({super.key, required this.profile});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  bool _on = false;

  Future<void> _toggle(bool v) async {
    setState(() => _on = v);
    await db.from('profiles').update({'online': v}).eq('id', db.auth.currentUser!.id);
  }

  Future<void> _accept(dynamic id) => db.from('trips').update({'driver_id': db.auth.currentUser!.id, 'status': 'accepted'}).eq('id', id).eq('status', 'requested');

  @override
  Widget build(BuildContext context) {
    final active = widget.profile['status'] == 'active';
    return Scaffold(
      appBar: AppBar(title: Text(t('driver')), actions: const [LangMenu(), SignOut()]),
      body: !active
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t('pending'), textAlign: TextAlign.center)))
          : Column(children: [
              SwitchListTile(value: _on, onChanged: _toggle, title: Text(t('online'))),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: db.from('trips').stream(primaryKey: ['id']).eq('status', 'requested'),
                  builder: (_, s) {
                    final rows = s.data ?? [];
                    if (!_on || rows.isEmpty) return Center(child: Text(t('none')));
                    return ListView(children: [
                      for (final r in rows)
                        ListTile(
                          title: Text('${r['pickup']} → ${r['dropoff']}'),
                          subtitle: Text('${r['fare']} FCFA'),
                          trailing: FilledButton(onPressed: () => _accept(r['id']), child: Text(t('accept'))),
                        ),
                    ]);
                  },
                ),
              ),
            ]),
    );
  }
}
