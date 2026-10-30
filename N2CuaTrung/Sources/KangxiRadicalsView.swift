import SwiftUI

/// Bảng phân loại 214 bộ thủ Khang Hy, biên soạn nghĩa ngắn bằng tiếng Việt.
/// Thứ tự theo 1–214. Bộ thủ KHÁC nghĩa toàn chữ Kanji và KHÁC nghĩa từ ghép.
/// Phần ánh xạ Kanji -> bộ thủ + âm Hán–Việt tham chiếu KANJIDIC2/EDRDG,
/// được phát hành theo CC BY-SA 4.0. Ghi công: EDRDG, James Breen;
/// bản JSON trung gian jkindrix/japanese-language-data (CC BY-SA 4.0).
struct KangxiRadical: Identifiable {
    let id: Int
    let character: String
    let sinoVietnamese: String
    let meaning: String
}

struct KanjiReferenceRecord {
    let radicalNumber: Int
    let sinoVietnamese: String
}

enum KangxiReference {
    private static let rawRadicals = """
一|nhất|một
丨|cổn|nét sổ dọc
丶|chủ|nét chấm
丿|phiệt|nét phẩy
乙|ất|thứ hai, nét cong
亅|quyết|nét móc
二|nhị|hai
亠|đầu|nắp phía trên
人|nhân|người
儿|nhi|chân người
入|nhập|vào
八|bát|tám, chia ra
冂|quynh|khung bao ngoài
冖|mịch|mái che
冫|băng|băng, nước đá
几|kỷ|bàn thấp
凵|khảm|hộp mở phía trên
刀|đao|con dao
力|lực|sức lực
勹|bao|bao bọc
匕|chủy|cái thìa
匚|phương|hộp mở một bên
匸|hệ|che giấu
十|thập|mười
卜|bốc|xem bói
卩|tiết|đốt tre, dấu ấn
厂|hán|vách núi
厶|tư|riêng tư
又|hựu|lại, bàn tay phải
口|khẩu|miệng
囗|vi|vây quanh
土|thổ|đất
士|sĩ|người học, kẻ sĩ
夂|trĩ|bước tới
夊|tuy|đi chậm
夕|tịch|buổi tối
大|đại|to, lớn
女|nữ|phụ nữ
子|tử|con cái
宀|miên|mái nhà
寸|thốn|tấc
小|tiểu|nhỏ
尢|uông|chân bị tật
尸|thi|xác, thân người
屮|triệt|mầm cây
山|sơn|núi
巛|xuyên|sông
工|công|công việc
己|kỷ|bản thân
巾|cân|khăn
干|can|cái khiên
幺|yêu|nhỏ bé
广|nghiễm|mái nhà nghiêng
廴|dẫn|bước dài
廾|củng|hai tay nâng
弋|dặc|đóng cọc, bắn
弓|cung|cây cung
彐|kệ|đầu, mõm lợn
彡|sam|lông, hoa văn
彳|xích|bước chân trái
心|tâm|tim, lòng
戈|qua|giáo mác
戶|hộ|cửa
手|thủ|tay
支|chi|cành, nhánh
攴|phộc|đánh nhẹ
文|văn|chữ viết
斗|đẩu|đấu đong
斤|cân|cái rìu
方|phương|vuông, hướng
无|vô|không có
日|nhật|mặt trời, ngày
曰|viết|nói rằng
月|nguyệt|mặt trăng, tháng
木|mộc|cây, gỗ
欠|khiếm|thiếu, ngáp
止|chỉ|dừng lại
歹|đãi|xương tàn
殳|thù|vũ khí, đánh
毋|vô|chớ, đừng
比|tỷ|so sánh
毛|mao|lông
氏|thị|họ, dòng họ
气|khí|hơi, khí
水|thủy|nước
火|hỏa|lửa
爪|trảo|móng vuốt
父|phụ|cha
爻|hào|vạch hào
爿|tường|mảnh gỗ
片|phiến|mảnh, tấm
牙|nha|răng nanh
牛|ngưu|trâu bò
犬|khuyển|chó
玄|huyền|huyền bí, đen sẫm
玉|ngọc|đá quý
瓜|qua|dưa
瓦|ngõa|ngói
甘|cam|ngọt
生|sinh|sinh ra, sống
用|dụng|dùng
田|điền|ruộng
疋|sơ|cuộn vải
疒|nạch|bệnh tật
癶|bát|bước chân dạng ra
白|bạch|trắng
皮|bì|da
皿|mãnh|đĩa, chén
目|mục|mắt
矛|mâu|cây mâu
矢|thỉ|mũi tên
石|thạch|đá
示|thị|chỉ dẫn, tế lễ
禸|nhựu|vết chân thú
禾|hòa|lúa
穴|huyệt|hang, lỗ
立|lập|đứng
竹|trúc|tre
米|mễ|gạo
糸|mịch|sợi tơ
缶|phẫu|đồ sành, vò
网|võng|lưới
羊|dương|dê
羽|vũ|lông vũ
老|lão|già
而|nhi|mà, và
耒|lỗi|cái cày
耳|nhĩ|tai
聿|duật|bút
肉|nhục|thịt
臣|thần|bề tôi
自|tự|bản thân
至|chí|đến
臼|cữu|cối giã
舌|thiệt|lưỡi
舛|suyễn|trái ngược
舟|chu|thuyền
艮|cấn|dừng lại
色|sắc|màu sắc
艸|thảo|cỏ
虍|hô|hổ
虫|trùng|sâu bọ
血|huyết|máu
行|hành|đi lại
衣|y|áo quần
襾|á|che phủ
見|kiến|nhìn thấy
角|giác|sừng
言|ngôn|lời nói
谷|cốc|thung lũng
豆|đậu|đậu
豕|thỉ|heo
豸|trãi|loài thú
貝|bối|vỏ sò
赤|xích|đỏ
走|tẩu|chạy
足|túc|chân
身|thân|thân thể
車|xa|xe
辛|tân|cay
辰|thần|buổi sớm
辵|sước|đi, bước
邑|ấp|làng ấp
酉|dậu|rượu
釆|biện|phân biệt
里|lý|làng, dặm
金|kim|kim loại, vàng
長|trường|dài
門|môn|cửa
阜|phụ|gò đất
隶|đãi|bắt kịp
隹|chuy|chim đuôi ngắn
雨|vũ|mưa
靑|thanh|xanh
非|phi|không phải
面|diện|mặt
革|cách|da thuộc, thay đổi
韋|vi|da đã thuộc
韭|cửu|rau hẹ
音|âm|âm thanh
頁|hiệt|đầu, trang
風|phong|gió
飛|phi|bay
食|thực|ăn, thức ăn
首|thủ|đầu
香|hương|mùi thơm
馬|mã|ngựa
骨|cốt|xương
高|cao|cao
髟|bưu|tóc dài
鬥|đấu|đánh nhau
鬯|sưởng|rượu cúng
鬲|cách|nồi ba chân
鬼|quỷ|ma quỷ
魚|ngư|cá
鳥|điểu|chim
鹵|lỗ|đất mặn
鹿|lộc|hươu
麥|mạch|lúa mạch
麻|ma|cây gai
黃|hoàng|màu vàng
黍|thử|hạt kê
黑|hắc|đen
黹|chỉ|thêu thùa
黽|mãnh|ếch, cóc
鼎|đỉnh|vạc ba chân
鼓|cổ|trống
鼠|thử|chuột
鼻|tị|mũi
齊|tề|đều, ngay ngắn
齒|xỉ|răng
龍|long|rồng
龜|quy|rùa
龠|dược|sáo
"""
    private static let rawKanji = """
並|1|Tịnh
丸|3|Hoàn
丼|3|Đảm, Tỉnh
久|4|Cửu
乱|5|Loạn, Làn, Loàn
乳|5|Nhũ
乾|5|Kiền, Can
了|6|Liễu
介|9|Giới
仏|9|Phật
令|9|Lệnh, Linh
仲|9|Trọng
任|9|Nhâm, Nhậm
伸|9|Thân
伺|9|Tý, Tứ
低|9|Đê
供|9|Cung
依|9|Y, Ỷ
個|9|Cá
倍|9|Bội
停|9|Đình
備|9|Bị
傾|9|Khuynh
像|9|Tượng
億|9|Ức
兆|10|Triệu
児|10|Nhi
党|10|Đảng
兵|12|Binh
冊|13|Sách, Sạch
再|13|Tái
凍|15|Đống
出|17|Xuất, Xúy
刊|18|Khan, San
判|18|Phán
刷|18|Xoát, Loát
券|18|Khoán
刺|18|Thứ, Thích
則|18|Tắc
副|18|Phó
劇|18|Kịch
加|19|Gia
努|19|Nỗ
効|19|Hiệu
勇|19|Dũng
募|19|Mộ
勢|19|Thế
勤|19|Cần
匂|20|Cái
包|20|Bao
匹|23|Thất
区|23|Âu, Khu
卒|24|Tốt, Tuất, Thốt
協|24|Hiệp
占|25|Chiêm, Chiếm
印|26|Ấn
卵|26|Noãn
厚|27|Hậu
原|27|Nguyên
参|28|Sâm, Tam, Tảm, Tham, Xam, Khươm
双|29|Song
叫|30|Khiếu
召|30|Triệu
史|30|Sử
各|30|Các
向|30|Hướng
含|30|Hàm
告|30|Cáo, Cốc, Cáu, Kiếu
周|30|Chu
咲|30|Tiếu
善|30|Thiện, Thiến
喫|30|Khiết
営|30|Dinh, Doanh
嗅|30|Khứu
因|31|Nhân
団|31|Đoàn
囲|31|Vi
固|31|Cố
圧|32|Áp, Yểm, Yếp
坂|32|Phản
均|32|Quân, Vận
型|32|Hình
埋|32|Mai
城|32|Thành
域|32|Vực
報|32|Báo
塔|32|Tháp
塗|32|Đồ, Trà
塞|32|Tắc, Tái
塩|32|Diêm
境|32|Cảnh
増|32|Tăng
売|33|Mại, Xác, Xạc
変|34|Biến, Bén, Biếng
央|37|Ương
契|37|Khế, Tiết, Khiết, Khất
奥|37|Áo, Úc
姓|38|Tính
委|38|Ủy, Uy
孝|39|Hiếu
季|39|Quý
孫|39|Tôn, Tốn
宇|40|Vũ
宛|40|Uyển, Uyên
宝|40|Bảo, Báu, Bửu
寺|41|Tự
対|41|Đối
寿|41|Thọ
封|41|Phong
専|41|Chuyên
将|41|Thương, Tương, Tướng
尊|41|Tôn
導|41|Đạo
届|44|Giới
層|44|Tằng
岩|46|Nham
岸|46|Ngạn
島|46|Đảo
州|47|Châu
巨|48|Cự, Há
巻|49|Quyển
巾|50|Cân
市|50|Thị
布|50|Bố
希|50|Hy
帯|50|Đái, Đới, Đai
帽|50|Mạo
幅|50|Phúc, Bức
干|51|Can
幼|52|Ấu
庁|53|Sảnh, Thinh
床|53|Sàng
底|53|Để
府|53|Phủ
庫|53|Khố
延|54|Duyên
弱|57|Nhược
影|59|Ảnh
律|60|Luật
復|60|Phục, Phúc
応|61|Ứng
快|61|Khoái
恋|61|Luyến
患|61|Hoạn
悩|61|Não
慣|61|Quán
慮|61|Lự, Lư
憎|61|Tăng
成|62|Thành
戸|63|Hộ, Họ
承|64|Thừa
技|64|Kĩ
担|64|Đam, Đảm, Đãn, Đản, Đẵm, Đán, Đắn, Đẵn, Dằng, Đét, Đởm, Dứt, Đứt, Tạ
拝|64|Bài
拭|64|Thức
拾|64|Thập, Thiệp, Kiệp
挟|64|Cáp, Hiệp, Tiệp, Giáp
捜|64|Sưu
捨|64|Xả
捻|64|Niệp, Niệm
掃|64|Tảo
掘|64|Quật
採|64|Thải, Thái
接|64|Tiếp
提|64|Đề, Thì, Để
換|64|Hoán
援|64|Viên, Viện
損|64|Tổn
改|66|Cải
敬|66|Kính
整|66|Chỉnh
斬|69|Trảm
断|69|Đoán, Đoạn, Đón
旧|72|Cựu, Cậu
昇|72|Thăng
星|72|Tinh
普|72|Phổ
暴|72|Bạo, Bộc
曇|72|Đàm
替|73|Thế
札|75|Trát
机|75|Cơ, Ki, Kỉ, Ky, Kỷ
材|75|Tài
村|75|Thôn
板|75|Bản
枕|75|Chẩm, Chấm
林|75|Lâm
枚|75|Mai
果|75|Quả
枝|75|Chi, Kỳ
枯|75|Khô
柔|75|Nhu
柱|75|Trụ, Trú
査|75|Tra
栄|75|Vinh
根|75|Căn
桁|75|Hành, Hàng, Hãng
械|75|Giới
棒|75|Bổng
森|75|Sâm
植|75|Thực, Trĩ
極|75|Cực
標|75|Tiêu, Phiêu
橋|75|Kiều, Khiêu, Cao
欧|76|Âu, Ẩu
武|77|Vũ, Võ
歴|77|Lịch
殿|79|Điện, Điến
毒|80|Độc, Đốc
比|81|Bỉ, Bí, Bì, Tỉ
毛|82|Mao, Mô
氷|85|Băng
永|85|Vĩnh
汗|85|Hãn, Hàn
汚|85|Ô, Ố, Phiếm
池|85|Trì
沈|85|Trầm, Thẩm, Trấm
河|85|Hà
沸|85|Phí, Phất
油|85|Du
況|85|Huống
泉|85|Tuyền, Toàn
泊|85|Bạc, Phách
波|85|Ba
泥|85|Nê, Nệ, Nễ
浅|85|Thiển, Tiên
浴|85|Dục
涙|85|Lệ
液|85|Dịch
涼|85|Lương, Lượng
混|85|Hỗn, Cổn
清|85|Thanh
減|85|Giảm
温|85|Ôn, Uẩn, Ồn, Ổn, Un
測|85|Trắc
湖|85|Hồ
湯|85|Thang, Sương, Thãng
湾|85|Loan
湿|85|Chập, Sấp, Thấp
源|85|Nguyên
準|85|Chuẩn, Chuyết
溶|85|Dong
滴|85|Tích, Trích
漁|85|Ngư
潰|85|Hội
濃|85|Nùng
濯|85|Trạc
灯|86|Đăng
灰|86|Hôi, Khôi
災|86|Tai
炭|86|Thán
焼|86|Thiêu
煎|86|Tiên, Tiễn
照|86|Chiếu
燃|86|Nhiên
燥|86|Táo
爆|86|Bạo, Bạc, Bộc
爪|87|Trảo
片|91|Phiến
版|91|Bản
状|94|Trạng
狙|94|Thư
率|95|Suất, Súy, Luật, Soát
玉|96|Ngọc, Túc
珍|96|Trân
環|96|Hoàn
瓦|98|Ngõa
瓶|98|Bình
甘|99|Cam
申|102|Thân
画|102|Hoạch
畜|102|Súc, Húc
略|102|Lược
畳|102|Điệp
療|104|Liệu
皮|107|Bì
皿|108|Mãnh
目|109|Mục
省|109|Tỉnh
県|109|Huyền
短|111|Đoản
砂|112|Sa
硬|112|Ngạnh
確|112|Xác
磨|112|Ma, Má
祈|113|Kì
祝|113|Chúc, Chú
祭|113|Tế, Sái
禁|113|Cấm, Câm
秒|115|Miểu
移|115|Di, Dị, Sỉ
税|115|Thoát, Thối, Thuế, Thuê
稽|115|Kê, Khể
章|117|Chương
童|117|Đồng
競|117|Cạnh
竹|118|Trúc
符|118|Phù
筆|118|Bút
筒|118|Đồng
箋|118|Tiên
算|118|Toán
管|118|Quản
築|118|Trúc
簡|118|Giản
籍|118|Tịch, Tạ
粉|119|Phấn
粒|119|Lạp
糸|120|Mịch
約|120|Ước
紅|120|Hồng
納|120|Nạp
純|120|Thuần, Chuẩn, Đồn, Truy
細|120|Tế
紹|120|Thiệu
経|120|Kinh
結|120|Kết
絡|120|Lạc
給|120|Cấp
統|120|Thống
継|120|Bối, Kế
続|120|Tục
綿|120|Miên
総|120|Tổng
緑|120|Lục
線|120|Tuyến
締|120|Đề
編|120|Biên
練|120|Luyện
績|120|Tích
缶|121|Phữu, Phẫu, Phũ
署|122|Thự
群|123|Quần
羨|123|Tiện
羽|124|Vũ
翌|124|Dực
耕|127|Canh
職|128|Chức
肌|130|Cơ
肘|130|Trửu
肩|130|Kiên
肯|130|Khẳng, Khải
胃|130|Vị
胸|130|Hung
能|130|Năng, Nai, Nại
脂|130|Chi
脳|130|Não
腕|130|Oản
腰|130|Yêu
膚|130|Phu
臓|130|Tạng
臣|131|Thần
舟|137|Chu
航|137|Hàng
般|137|Bàn, Ban, Bát
芯|140|Tâm
芸|140|Vân
荒|140|Hoang
荷|140|Hà
菓|140|Quả
菜|140|Thái
著|140|Trứ
蒸|140|Chưng
蓋|140|Cái
蔵|140|Tàng, Tạng
薄|140|Bạc, Bác
虫|142|Trùng
血|143|Huyết
衣|145|Y, Ý
袋|145|Đại
被|145|Bị, Bí
装|145|Trang
裏|145|Lý
補|145|Bổ
製|145|Chế
複|145|Phức
規|147|Quy
角|148|Giác, Giốc
触|148|Xúc
計|149|Kế, Kê
訓|149|Huấn
設|149|Thiết
証|149|Chứng
詞|149|Từ
詰|149|Cật
誌|149|Chí
認|149|Nhận
説|149|Duyệt, Thoát, Thuế, Thuyết, Thót, Thốt
課|149|Khóa
調|149|Điều, Điệu
請|149|Thỉnh, Tính
諸|149|Chư
講|149|Giảng
議|149|Nghị
谷|150|Cốc, Lộc, Dục
豊|151|Lễ, Phong
象|152|Tượng
貝|154|Bối
貨|154|Hóa
販|154|Phiến, Phán
責|154|Trách, Trái
貯|154|Trữ
貿|154|Mậu
資|154|Tư
賞|154|Thưởng
賢|154|Hiền
贈|154|Tặng
超|156|Siêu
跡|157|Tích
踊|157|Dũng
蹴|157|Xúc
軍|159|Quân
軒|159|Hiên
軟|159|Nhuyễn
軽|159|Khinh
較|159|Giác, Giếu, Giảo
輪|159|Luân
輸|159|Thâu, Thú
辛|160|Tân
農|161|Nông
辺|162|Biên
述|162|Thuật
逆|162|Nghịch, Nghịnh
造|162|Tạo, Tháo
連|162|Liên
達|162|Đạt
遜|162|Tốn
遡|162|Tố
避|162|Tị
郊|163|Giao
郵|163|Bưu
都|163|Đô
量|166|Lượng, Lương
釜|167|Phủ
針|167|Châm
鈍|167|Độn
鉄|167|Thiết
鉱|167|Khoáng
銅|167|Đồng
鋭|167|Duệ, Nhuệ
録|167|Lục
門|169|Môn
防|170|Phòng
陸|170|Lục
険|170|Hiểm
隅|170|Ngung
階|170|Giai
隙|170|Khích
隻|172|Chích
雇|172|Cố
難|172|Nan, Nạn
雲|173|Vân
零|173|Linh
需|173|Nhu
震|173|Chấn
革|177|Cách, Cức
響|180|Hưởng
順|181|Thuận
預|181|Dự
領|181|Lĩnh
額|181|Ngạch
餅|184|Bính
香|186|Hương
駐|187|Trú
験|187|Nghiệm
骨|188|Cốt
麓|198|Lộc
麦|199|Mạch
黄|201|Hoàng
鼻|209|Tị
齢|211|Linh
"""

    static let radicals: [KangxiRadical] = rawRadicals
        .split(separator: "\n")
        .enumerated()
        .compactMap { index, line in
            let pieces = line.split(separator: "|", omittingEmptySubsequences: false)
            guard pieces.count == 3 else { return nil }
            return KangxiRadical(id: index + 1,
                                 character: String(pieces[0]),
                                 sinoVietnamese: String(pieces[1]),
                                 meaning: String(pieces[2]))
        }

    static let byNumber = Dictionary(uniqueKeysWithValues: radicals.map { ($0.id, $0) })

    private static let aliases: [String: Int] = [
        "亻": 9, "⺅": 9, "刂": 18, "忄": 61, "⺗": 61,
        "扌": 64, "攵": 66, "氵": 85, "氺": 85, "灬": 86,
        "牜": 93, "犭": 94, "礻": 113, "⺮": 118,
        "罒": 122, "⺶": 123, "⺼": 130, "艹": 140,
        "衤": 145, "訁": 149, "辶": 162, "釒": 167,
        "飠": 184, "戸": 63, "麦": 199, "黄": 201,
        "黒": 203, "青": 174, "竜": 212, "亀": 213, "歯": 211, "斉": 210
    ]

    private static let numberByRadical = Dictionary(uniqueKeysWithValues:
        radicals.map { ($0.character, $0.id) })

    static let kanjiReferences: [String: KanjiReferenceRecord] = {
        var result: [String: KanjiReferenceRecord] = [:]
        for line in rawKanji.split(separator: "\n") {
            let fields = line.split(separator: "|", omittingEmptySubsequences: false)
            guard fields.count == 3, let number = Int(fields[1]),
                  (1...214).contains(number) else { continue }
            result[String(fields[0])] = KanjiReferenceRecord(
                radicalNumber: number, sinoVietnamese: String(fields[2]))
        }
        return result
    }()

    static func info(for kanji: String) -> KanjiReferenceRecord? {
        kanjiReferences[kanji]
    }

    static func radical(for character: String) -> KangxiRadical? {
        if let exact = numberByRadical[character] { return byNumber[exact] }
        if let alias = aliases[character] { return byNumber[alias] }
        return nil
    }

    static func radical(forKanji character: String) -> KangxiRadical? {
        guard let n = info(for: character)?.radicalNumber else {
            return radical(for: character)
        }
        return byNumber[n]
    }
}

struct KangxiRadicalsView: View {
    @State private var search = ""

    private var filtered: [KangxiRadical] {
        KangxiReference.radicals.filter { r in
            search.isEmpty || String(r.id).contains(search) ||
            r.character.contains(search) ||
            r.sinoVietnamese.localizedCaseInsensitiveContains(search) ||
            r.meaning.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            Section {
                Text("214 bộ thủ dùng để phân loại và tra chữ Hán. Bộ thủ không đồng nghĩa với toàn bộ chữ Kanji và cũng không phải nghĩa của một từ ghép tiếng Nhật.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("214 bộ thủ Khang Hy") {
                ForEach(filtered) { r in
                    HStack(spacing: 14) {
                        Text(r.character)
                            .font(.system(size: 34, weight: .medium))
                            .frame(width: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bộ #\(r.id) • \(r.sinoVietnamese.capitalized)")
                                .font(.headline)
                            Text(r.meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .searchable(text: $search, prompt: "Tìm bộ, âm Hán–Việt hoặc nghĩa")
        .navigationTitle("214 bộ thủ")
    }
}
