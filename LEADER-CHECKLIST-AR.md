# قائمة تجهيز الليدر

## الموجود والمؤكد

- [x] مستودع GitHub خاص: Alshaya-A/SDA-project-FoxFlow.
- [x] اشتراك Azure فعال: Azure subscription 1.
- [x] مجموعة rg-foxflow-demo في uaenorth وبداخلها VM وشبكة وأقراص.
- [x] دليل بداية محلي ورسالة لجمع بيانات الفريق.

## بيانات الفريق والدعوات

- [ ] استلام الأسماء وحسابات GitHub وبريد الدعوات وتوزيع الأدوار.
- [ ] دعوة الأعضاء للمستودع الحالي عبر Settings → Collaborators.
- [ ] التحقق من قبول الدعوات وقدرة كل عضو على clone ورفع فرع.
- [ ] تفعيل المصادقة الثنائية لكل حساب.

المستودع الحالي شخصي: الأعضاء Collaborators مع وصول كتابة، وليس أدوار Organization المتعددة. يبقى Alshaya-A المالك. لا حاجة لنقل المستودع أو إنشاء Organization كي يبدأ الفريق.

## GitHub

- [ ] رفع دليل البداية إلى المستودع.
- [ ] إنشاء أربع Issues باستخدام FIRST-TASKS-AR.md وإسنادها بعد معرفة الحسابات.
- [ ] إنشاء GitHub Project باسم FoxFlow Delivery وربطه بالمستودع.
- [ ] حالات اللوحة: Todo، In progress، In review، Done.
- [ ] حماية main بطلب مراجعة واحدة ومنع force push والحذف إذا كانت خطة الحساب تدعم حماية المستودعات الخاصة.
- [ ] إذا لم تدعم الخطة الحماية: توثيق أن قاعدة PR تنظيمية وغير مفروضة تقنيًا؛ لا اشتراك مدفوع ولا تحويل إلى Public دون قرار الليدر.

## Discord

- [ ] استخدام سيرفر FoxFlow الموجود إن وجد أو إنشاء سيرفر واحد.
- [ ] إنشاء قنوات announcements، general، help، pipeline-alerts وغرفة صوتية meeting.
- [ ] الليدر يدير السيرفر، والأعضاء بدور Member. لا حاجة لمنح Administrator للجميع.
- [ ] إنشاء رابط دعوة محدود المدة وإضافته للرسالة النهائية.
- [ ] لا حاجة للبوتات أو webhook في أول يوم؛ يجهز ربط الإشعارات مع العضو 4 لاحقًا.

## Google Drive

- [ ] مجلد FoxFlow Team وفيه Slides وEvidence وMeetings.
- [ ] دعوة أعضاء الفريق فقط بصلاحية Editor على المجلد.
- [ ] إضافة الرابط إلى الرسالة. يبقى توثيق التشغيل داخل GitHub.

## Azure

- [ ] تحديد صاحب كل دور وتأكيد استخدام rg-foxflow-demo للتجربة المشتركة.
- [ ] إضافة أعضاء Entra كضيوف إذا لزم، ثم توزيع RBAC على نطاق موارد المشروع.
- [ ] العضو 1: Contributor على مجموعة المشروع. تعيين أدوار الهوية ينفذه الليدر؛ Contributor وحده لا يستطيع تعيين RBAC.
- [ ] العضو 2: Reader عند الحاجة، وحساب SSH مستقل بإدارة النظام وفق المهمة.
- [ ] العضو 3: لا وصول Azure مطلوب بالبداية، أو Reader للتعلّم عند الحاجة.
- [ ] العضو 4: Reader عند الحاجة وهوية نشر محددة؛ لا تعطه Owner للاشتراك.
- [ ] تحديد التخزين الحالي لـTerraform State قبل تغيير البنية. الوصول بـEntra إلى الحاوية يحتاج Storage Blob Data Contributor لمن ينفذ Terraform.
- [ ] تحديد سقف ميزانية شهري وتنبيهات. التنبيه لا يوقف الإنفاق تلقائيًا.
- [ ] التحقق من حالة VM وGitLab وRunner والمنافذ وإعدادات HTTPS قبل إرسال رابط المنصة.
- [ ] لا إنشاء سيرفر ثانٍ أو تغيير شبكة البيئة قبل مراجعة الموجود.

## GitLab — عند جاهزية المنصة

- [ ] إنشاء group foxflow ومشروع sample-app.
- [ ] الليدر Owner للمجموعة؛ العضوان 2 و4 Maintainer للمشروع؛ العضوان 1 و3 Developer.
- [ ] فصل صلاحية إدارة خادم GitLab عن صلاحيات المشروع؛ لا يحتاج الجميع حساب admin.
- [ ] حساب مستقل لكل عضو واختبار تسجيل الدخول.
- [ ] تسجيل Runner بوسم foxflow واختبار Job فعلية.
- [ ] تخزين أسرار CI في متغيرات GitLab مع الإخفاء والحماية المناسبة، لا في ملف YAML.
- [ ] توثيق مزامنة التطبيق من GitHub إلى GitLab، ثم اختبار Pipeline والإشعار.

## مراجع الصلاحيات

- https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-personal-account-settings/permission-levels-for-a-personal-account-repository
- https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
- https://docs.gitlab.com/user/permissions/
